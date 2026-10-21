{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dtv;
  inherit (lib)
    mkOption
    types
    mkIf
    mkMerge
    ;
  settingsType = (pkgs.formats.json { }).type;
  drivers = import ./drivers.nix;
  nonEmpty = types.addCheck types.str (s: s != "");
  localTypes = builtins.attrNames drivers ++ [ "dvb" ];
  isLocal = t: builtins.elem t.driver localTypes;
  capturing = t: t.mode != [ ];
  indexed = lib.imap0 (
    i: t:
    t
    // {
      cardIndex =
        builtins.length (
          builtins.filter (p: p.enable && p.driver == t.driver && p.mode == null) (lib.take i cfg.tuners)
        )
        + 1;
    }
  ) cfg.tuners;
  expanded = lib.concatLists (
    lib.imap0 (
      i: t:
      if t.driver == "pt3" && t.mode == null then
        map
          (
            channel:
            t
            // {
              name = "${if t.name != null && t.name != "" then t.name else "PT3"}-${channel.band}${
                toString ((t.cardIndex - 1) * 2 + channel.number)
              }";
              mode = channel.mode;
              device = "/dev/pt3video${
                toString (
                  (if t.deviceOffset == null then (t.cardIndex - 1) * 4 else t.deviceOffset) + channel.offset
                )
              }";
            }
          )
          [
            {
              band = "T";
              number = 1;
              mode = [ "GR" ];
              offset = 2;
            }
            {
              band = "T";
              number = 2;
              mode = [ "GR" ];
              offset = 3;
            }
            {
              band = "S";
              number = 1;
              mode = [
                "BS"
                "CS"
              ];
              offset = 0;
            }
            {
              band = "S";
              number = 2;
              mode = [
                "BS"
                "CS"
              ];
              offset = 1;
            }
          ]
      else
        [ (t // { mode = if t.mode == null then [ ] else t.mode; }) ]
    ) indexed
  );
  nameGroup =
    t:
    if !capturing t then
      "${lib.toUpper t.driver}-hardware-"
    else if t.driver == "pt3" || t.driver == "px4" then
      "${lib.toUpper t.driver}-${if builtins.elem "GR" t.mode then "T" else "S"}"
    else if
      builtins.elem "BS4K" t.mode
      && builtins.elem t.driver [
        "tbs6812"
        "hiraku"
      ]
    then
      "PT4K-"
    else
      "${lib.toUpper t.driver}-";
  named = lib.imap0 (
    i: t:
    let
      group = nameGroup t;
      number =
        builtins.length (builtins.filter (p: p.enable && nameGroup p == group) (lib.take i expanded)) + 1;
      name = if t.name != null && t.name != "" then t.name else "${group}${toString number}";
    in
    t
    // {
      inherit name;
      serve = t.serve // {
        mode = if t.serve.mode == "" then name else t.serve.mode;
        modeBS4K = if t.serve.modeBS4K == "" then "${name}-BS4K" else t.serve.modeBS4K;
      };
    }
  ) expanded;
  enabled = builtins.filter (t: t.enable) named;
  sources = builtins.filter capturing enabled;
  locals = builtins.filter isLocal sources;
  exported = builtins.filter (t: t.serve.enable) locals;
  selectedDrivers = lib.unique (
    map (t: t.driver) (builtins.filter (t: builtins.hasAttr t.driver drivers) enabled)
  );
  driverPackages = lib.genAttrs selectedDrivers (
    name: config.boot.kernelPackages.callPackage drivers.${name}.file { }
  );
  has4k = t: builtins.elem "BS4K" t.mode;
  recorder =
    t:
    if
      builtins.elem t.driver [
        "pt3"
        "px4"
      ]
    then
      cfg.packages.recpt1
    else
      cfg.packages.recdvb;
  localCommand =
    t: fourK:
    [
      (
        if fourK then
          lib.getExe' cfg.packages.recdvb4k "recdvb4k"
        else
          lib.getExe' (recorder t) (
            if
              builtins.elem t.driver [
                "pt3"
                "px4"
              ]
            then
              "recpt1"
            else
              "recdvb"
          )
      )
      (
        if
          builtins.elem t.driver [
            "pt3"
            "px4"
          ]
        then
          "--device"
        else
          "--dev"
      )
      (if t.device != null then t.device else "")
    ]
    ++ lib.optional t.strip "--strip"
    ++ lib.optional (if fourK then t.b61 else t.b25) (if fourK then "--b61" else "--b25")
    ++ (if fourK then t.argsBS4K else t.args)
    ++ [
      "<channel>"
      "-"
      "-"
    ];
  argv =
    t: fourK:
    if fourK && t.commandBS4K != [ ] then
      t.commandBS4K
    else if !fourK && t.command != [ ] then
      t.command
    else if t.driver == "hiraku" then
      [
        (lib.getExe' cfg.packages.hiraku "hiraku")
        t.hiraku.address
        t.hiraku.secret
        (if fourK then t.hiraku.modeBS4K else t.hiraku.mode)
        "<channel>"
      ]
    else
      localCommand t fourK;
  # Mirakurun's command parser does not implement shell escaping. Keep only the
  # channel placeholder in its command string; pass all other arguments through
  # a generated executable with proper argv quoting.
  commandString =
    t: fourK:
    let
      script = pkgs.writeShellScript "dtv-tuner" (
        "exec "
        + lib.concatMapStringsSep " " (
          arg: if arg == "<channel>" then ''"$1"'' else lib.escapeShellArg arg
        ) (argv t fourK)
      );
    in
    "${script} <channel>";
  bs4kCommand =
    t:
    has4k t
    && (
      t.driver == "tbs6812" || t.driver == "hiraku" && t.hiraku.modeBS4K != null || t.commandBS4K != [ ]
    );
  nativeTuner =
    t:
    t.settings
    // {
      inherit (t) name;
      types = t.mode;
      isDisabled = false;
    }
    // (
      if t.driver == "remote" then
        {
          remoteMirakurunHost = t.remote.host;
          remoteMirakurunPort = t.remote.port;
          remoteMirakurunDecoder = t.remote.decoder;
          remoteMirakurunAllowNested = t.remote.allowNested;
        }
      else
        {
          command = commandString t false;
        }
        // lib.optionalAttrs (bs4kCommand t) { commandBS4K = commandString t true; }
        // lib.optionalAttrs (isLocal t && t.device != null && lib.hasPrefix "/dev/" t.device) {
          checkDevicePath = t.device;
        }
        // lib.optionalAttrs (has4k t && t.mmtsDecoder) {
          mmtsDecoder = "${lib.getExe' cfg.packages.dantto4k "dantto4k"} --frontend-descrambled - -";
        }
    );
  dependencies =
    t:
    t.packages
    ++ lib.optional (isLocal t) (recorder t)
    ++ lib.optional (t.driver == "tbs6812" && has4k t) cfg.packages.recdvb4k
    ++ lib.optional (t.driver == "hiraku") cfg.packages.hiraku
    ++ lib.optional (t.driver != "remote" && has4k t && t.mmtsDecoder) cfg.packages.dantto4k;
  modes = lib.concatMap (
    t:
    [
      {
        name = t.serve.mode;
        value.record = [ (argv t false) ];
      }
    ]
    ++ lib.optional (bs4kCommand t) {
      name = t.serve.modeBS4K;
      value.record = [ (argv t true) ];
    }
  ) exported;
  names = map (t: t.name) enabled;
  modeNames = map (m: m.name) modes;
  activeLocals =
    if cfg.mirakurun.enable then
      locals
    else if cfg.hirakud.enable then
      exported
    else
      [ ];
  pcsc = config.services.pcscd.enable;
  endpoint = types.submodule {
    options = {
      host = mkOption {
        type = types.nullOr nonEmpty;
        default = null;
        description = "Remote Mirakurun host.";
      };
      port = mkOption {
        type = types.port;
        default = 40772;
        description = "Remote Mirakurun port.";
      };
      decoder = mkOption {
        type = types.bool;
        default = true;
        description = "Request decoding on the remote server.";
      };
      allowNested = mkOption {
        type = types.bool;
        default = false;
        description = "Allow nested remote tuner routing.";
      };
    };
  };
in
{
  options.dtv = {
    packages = lib.genAttrs [ "recpt1" "recdvb" "recdvb4k" "hiraku" "dantto4k" ] (
      name: lib.mkPackageOption pkgs name { }
    );
    tuners = mkOption {
      default = [ ];
      description = "Shared tuner inventory. Omitted mode expands a PT3 card; explicit mode describes one tuner, and [] declares hardware only.";
      type = types.listOf (
        types.submodule (
          { config, ... }: {
            options = {
              name = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Unique tuner name; defaults to driver and list index.";
              };
              enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable this inventory entry and its dependencies.";
              };
              driver = mkOption {
                type = types.enum (
                  localTypes
                  ++ [
                    "command"
                    "hiraku"
                    "remote"
                  ]
                );
                description = "Capture backend or local hardware driver.";
              };
              mode = mkOption {
                type = types.nullOr (types.listOf nonEmpty);
                default = null;
                description = "Broadcast modes; omitted for compact PT3 expansion, or [] for hardware only.";
              };
              deviceOffset = mkOption {
                type = types.nullOr types.ints.unsigned;
                default = null;
                description = "First PT3 device number; defaults to four devices per preceding compact PT3 card.";
              };
              device = mkOption {
                type = types.nullOr nonEmpty;
                default = null;
                description = "Device path for recpt1 or adapter number for recdvb.";
              };
              b25 = mkOption {
                type = types.bool;
                default = true;
                description = "Enable B25 decoding for local capture.";
              };
              b61 = mkOption {
                type = types.bool;
                default = true;
                description = "Enable B61 decoding for local BS4K capture.";
              };
              strip = mkOption {
                type = types.bool;
                default = true;
                description = "Strip unused TS packets during local capture.";
              };
              args = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Additional local recorder arguments.";
              };
              argsBS4K = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Additional local BS4K recorder arguments.";
              };
              command = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Explicit command argv; a <channel> argument is substituted at runtime.";
              };
              commandBS4K = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Explicit BS4K command argv.";
              };
              packages = mkOption {
                type = types.listOf types.package;
                default = [ ];
                description = "Additional command dependencies.";
              };
              mmtsDecoder = mkOption {
                type = types.bool;
                default = true;
                description = "Use dantto4k for a non-remote BS4K MMTS stream.";
              };
              settings = mkOption {
                type = settingsType;
                default = { };
                description = "Additional native Mirakurun tuner settings.";
              };
              remote = mkOption {
                type = endpoint;
                default = { };
                description = "Remote Mirakurun endpoint.";
              };
              hiraku = {
                address = mkOption {
                  type = types.nullOr nonEmpty;
                  default = null;
                  description = "Remote Hiraku address:port.";
                };
                secret = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Remote Hiraku authentication token.";
                };
                mode = mkOption {
                  type = types.nullOr nonEmpty;
                  default = null;
                  description = "Remote recording mode.";
                };
                modeBS4K = mkOption {
                  type = types.nullOr nonEmpty;
                  default = null;
                  description = "Remote BS4K recording mode.";
                };
              };
              serve = {
                enable = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Export this local capture when the Hirakud role is enabled.";
                };
                mode = mkOption {
                  type = types.str;
                  default = "";
                  description = "Hirakud recording mode; defaults to the generated tuner name.";
                };
                modeBS4K = mkOption {
                  type = types.str;
                  default = "";
                  description = "Hirakud BS4K mode; defaults to tuner name plus -BS4K.";
                };
              };
            };
          }
        )
      );
    };
    exports = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "Portable channel and tuner descriptions for another machine; endpoints and credentials are supplied by that consumer.";
    };
  };
  config = mkMerge [
    {
      assertions = [
        {
          assertion = builtins.all (t: !t.enable || t.driver == "pt3" || t.mode != null) cfg.tuners;
          message = "Non-PT3 tuners require explicit mode; use [] for hardware only.";
        }
        {
          assertion = builtins.all (
            t:
            builtins.all (key: !(builtins.hasAttr key t.settings)) [
              "name"
              "types"
              "command"
              "commandBS4K"
              "isDisabled"
              "checkDevicePath"
              "remoteMirakurunHost"
              "remoteMirakurunPort"
              "remoteMirakurunDecoder"
              "remoteMirakurunAllowNested"
              "mmtsDecoder"
            ]
          ) enabled;
          message = "Use dtv.tuners canonical fields instead of overriding them in settings.";
        }
        {
          assertion = builtins.length names == builtins.length (lib.unique names);
          message = "dtv.tuners names must be unique.";
        }
        {
          assertion = builtins.all (
            t: !isLocal t || !capturing t || t.device != null || t.command != [ ]
          ) enabled;
          message = "A local capture tuner requires device or command.";
        }
        {
          assertion = builtins.all (t: t.driver != "command" || !capturing t || t.command != [ ]) enabled;
          message = "A command tuner requires command argv.";
        }
        {
          assertion = builtins.all (t: t.driver != "remote" || t.remote.host != null) sources;
          message = "A remote tuner requires remote.host.";
        }
        {
          assertion = builtins.all (
            t:
            t.driver != "hiraku" || t.hiraku.address != null && t.hiraku.secret != null && t.hiraku.mode != null
          ) sources;
          message = "A Hiraku tuner requires hiraku.address, secret and mode.";
        }
      ];
      boot.extraModulePackages = map (name: driverPackages.${name}) selectedDrivers;
      boot.kernelModules = lib.unique (lib.concatMap (name: drivers.${name}.modules) selectedDrivers);
      boot.blacklistedKernelModules = lib.optional (builtins.elem "pt3" selectedDrivers) "earth_pt3";
      hardware.firmware = lib.optional (builtins.elem "px4" selectedDrivers) driverPackages.px4;
      dtv.exports = {
        channels = cfg.channels;
        hirakuTuners = map (t: {
          inherit (t) name mode;
          hiraku = {
            mode = if t.serve.mode == "" then t.name else t.serve.mode;
            modeBS4K =
              if bs4kCommand t then
                (if t.serve.modeBS4K == "" then "${t.name}-BS4K" else t.serve.modeBS4K)
              else
                null;
          };
        }) exported;
        mirakurunTuners = map (t: { inherit (t) name mode; }) sources;
      };
    }
    (mkIf (activeLocals != [ ]) {
      services.udev.extraRules = ''
        SUBSYSTEM=="ptx", GROUP="video", MODE="0660"
        KERNEL=="pt3video*", GROUP="video", MODE="0660"
        KERNEL=="px4video*", GROUP="video", MODE="0660"
        SUBSYSTEM=="dvb", GROUP="video", MODE="0660"
      '';
    })
    (mkIf cfg.mirakurun.enable {
      services.mirakurun.tunerSettings = map nativeTuner sources;
      systemd.services.mirakurun = {
        path = lib.unique (lib.concatMap dependencies sources);
        wants = [ "network-online.target" ] ++ lib.optional (locals != [ ] && pcsc) "pcscd.service";
        after = [ "network-online.target" ] ++ lib.optional (locals != [ ] && pcsc) "pcscd.service";
      };
    })
    (mkIf cfg.hirakud.enable {
      assertions = [
        {
          assertion = builtins.length modeNames == builtins.length (lib.unique modeNames);
          message = "Hiraku mode names must be unique.";
        }
      ];
      services.hirakud = {
        settings.modes = builtins.listToAttrs modes;
        path = lib.unique (lib.concatMap dependencies exported);
      };
      systemd.services.hirakud = {
        after = lib.optional (exported != [ ] && pcsc) "pcscd.service";
        wants = lib.optional (exported != [ ] && pcsc) "pcscd.service";
        serviceConfig.SupplementaryGroups = [ "video" ];
      };
    })
  ];
}
