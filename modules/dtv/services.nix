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
    mkEnableOption
    mkIf
    mkMerge
    types
    ;
  settingsType = (pkgs.formats.json { }).type;
  serviceOptions = name: {
    enable = mkEnableOption name;
    package = lib.mkPackageOption pkgs name { };
    settings = mkOption {
      type = settingsType;
      default = { };
      description = "Native application settings.";
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the service ports in the firewall.";
    };
  };
  localMirakurun = cfg.mirakurun.enable && !(cfg.epgstation.settings ? mirakurunPath);
  socket = cfg.mirakurun.listen.unixSocket;
in
{
  options.dtv = {
    channels = mkOption {
      type = types.listOf settingsType;
      default = [ ];
      description = "Mirakurun channel definitions, shared with exported tuner descriptions.";
    };
    mirakurun = serviceOptions "mirakurun" // {
      listen = {
        port = mkOption {
          type = types.nullOr types.port;
          default = 40772;
          description = "TCP port, or null to disable TCP.";
        };
        unixSocket = mkOption {
          type = types.nullOr types.str;
          default = "/var/run/mirakurun/mirakurun.sock";
          description = "Unix socket, or null to disable it.";
        };
        ipv6 = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Mirakurun's IPv6 listeners.";
        };
      };
    };
    epgstation = serviceOptions "epgstation" // {
      listen = lib.genAttrs [ "port" "socketioPort" "clientSocketioPort" ] (
        name:
        mkOption {
          type = types.port;
          default =
            if name == "port" then
              8888
            else if name == "socketioPort" then
              cfg.epgstation.listen.port + 1
            else
              cfg.epgstation.listen.socketioPort;
          description = "EPGStation ${name}.";
        }
      );
    };
    hirakud = {
      enable = mkEnableOption "the local Hiraku tuner relay role";
      package = lib.mkPackageOption pkgs "hiraku" { };
      listen = mkOption {
        type = types.str;
        default = "0.0.0.0:40773";
        description = "Native Hirakud bind address:port.";
      };
      port = mkOption {
        type = types.port;
        default = 40773;
        description = "Hirakud port used for the optional firewall rule; match listen.";
      };
      settings = mkOption {
        type = settingsType;
        default = { };
        description = "Hirakud settings, including authentication and optional additional modes.";
      };
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open Hirakud's port in the firewall.";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.mirakurun.enable {
      assertions = [
        {
          assertion = cfg.mirakurun.listen.port != null || socket != null;
          message = "dtv.mirakurun requires at least one TCP or Unix listener.";
        }
        {
          assertion =
            !(
              cfg.mirakurun.settings ? port
              || cfg.mirakurun.settings ? path
              || cfg.mirakurun.settings ? disableIPv6
            );
          message = "Configure Mirakurun listeners through dtv.mirakurun.listen.";
        }
      ];
      services.mirakurun = {
        enable = true;
        inherit (cfg.mirakurun) openFirewall;
        port = cfg.mirakurun.listen.port;
        unixSocket = socket;
        channelSettings = cfg.channels;
        serverSettings = cfg.mirakurun.settings // {
          port = cfg.mirakurun.listen.port;
          path = socket;
          disableIPv6 = !cfg.mirakurun.listen.ipv6;
        };
      };
      # The native module has no package option. Wire the selected executable
      # explicitly rather than exposing an option that cannot affect startup.
      systemd.services.mirakurun = {
        path = [ cfg.mirakurun.package ];
        serviceConfig.ExecStart = lib.mkForce "${lib.getExe' cfg.mirakurun.package "mirakurun"} start";
      };
    })
    (mkIf cfg.epgstation.enable {
      services.mirakurun.enable = cfg.mirakurun.enable;
      assertions = [
        {
          assertion = builtins.all (name: !(builtins.hasAttr name cfg.epgstation.settings)) [
            "port"
            "socketioPort"
            "clientSocketioPort"
          ];
          message = "Configure EPGStation ports through dtv.epgstation.listen.";
        }
        {
          assertion = cfg.mirakurun.enable || cfg.epgstation.settings ? mirakurunPath;
          message = "EPGStation requires dtv.mirakurun.enable or an explicit settings.mirakurunPath.";
        }
      ];
      services.epgstation = {
        enable = true;
        inherit (cfg.epgstation) package openFirewall;
        settings =
          cfg.epgstation.settings
          // cfg.epgstation.listen
          // lib.optionalAttrs localMirakurun {
            mirakurunPath =
              if socket != null then
                "http+unix://${lib.replaceStrings [ "/" ] [ "%2F" ] socket}"
              else
                "http://127.0.0.1:${toString cfg.mirakurun.listen.port}";
          };
      };
      systemd.services.epgstation = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ] ++ lib.optional localMirakurun "mirakurun.service";
      };
    })
    (mkIf cfg.hirakud.enable {
      services.hirakud = {
        enable = true;
        inherit (cfg.hirakud) package port openFirewall;
        settings = cfg.hirakud.settings // {
          listen = cfg.hirakud.listen;
        };
      };
    })
  ];
}
