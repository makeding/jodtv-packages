{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  linuxPkgs = import nixpkgs {
    system = "x86_64-linux";
    overlays = [ self.overlays.default ];
  };
  system =
    module:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        {
          system.stateVersion = "26.05";
          nixpkgs.config.allowUnfreePredicate =
            p:
            builtins.elem (lib.getName p) [
              "pcsc-rw5100"
            ];
        }
        module
      ];
    };
  configOf = module: (system module).config;
  assertionFails =
    message: module:
    builtins.any (assertion: assertion.message == message && !assertion.assertion)
      (configOf module).assertions;
  hasService = config: name: builtins.hasAttr name config.systemd.services;
  hasPackage = package: packages: builtins.any (p: lib.getName p == lib.getName package) packages;
  hasNamedPackage = name: packages: builtins.any (p: lib.getName p == name) packages;
  fakeExe =
    name:
    linuxPkgs.runCommand name { } ''
      mkdir -p $out/bin
      touch $out/bin/${name}
    '';

  hirakudOnly = configOf {
    dtv.hirakud.enable = true;
    dtv.channels = [
      {
        name = "example";
        type = "GR";
        channel = "13";
      }
    ];
    dtv.tuners = [
      {
        driver = "pt3";
      }
      {
        driver = "pt3";
      }
    ];
  };
  hirakudOnlyContract =
    !hasService hirakudOnly "mirakurun"
    &&
      builtins.attrNames hirakudOnly.services.hirakud.settings.modes == [
        "PT3-S1"
        "PT3-S2"
        "PT3-S3"
        "PT3-S4"
        "PT3-T1"
        "PT3-T2"
        "PT3-T3"
        "PT3-T4"
      ]
    &&
      map (t: t.name) hirakudOnly.dtv.exports.hirakuTuners == [
        "PT3-T1"
        "PT3-T2"
        "PT3-S1"
        "PT3-S2"
        "PT3-T3"
        "PT3-T4"
        "PT3-S3"
        "PT3-S4"
      ]
    && builtins.length hirakudOnly.boot.extraModulePackages == 1
    && builtins.length (builtins.filter (name: name == "pt3_drv") hirakudOnly.boot.kernelModules) == 1
    && !hirakudOnly.services.pcscd.enable
    &&
      map (t: t.mode) hirakudOnly.dtv.exports.mirakurunTuners == [
        [ "GR" ]
        [ "GR" ]
        [
          "BS"
          "CS"
        ]
        [
          "BS"
          "CS"
        ]
        [ "GR" ]
        [ "GR" ]
        [
          "BS"
          "CS"
        ]
        [
          "BS"
          "CS"
        ]
      ]
    && builtins.any (
      flag:
      lib.hasInfix (builtins.unsafeDiscardStringContext (toString hirakudOnly.boot.kernelPackages.kernel.dev)) flag
    ) (builtins.head hirakudOnly.boot.extraModulePackages).makeFlags;

  exportedHirakuConsumer = configOf {
    dtv.mirakurun.enable = true;
    dtv.channels = hirakudOnly.dtv.exports.channels;
    dtv.tuners = self.lib.mkHirakuTuners {
      tuners = hirakudOnly.dtv.exports.hirakuTuners;
      address = "relay.example:40773";
      secret = "test-only";
    };
  };
  exportedHirakuConsumerContract =
    exportedHirakuConsumer.dtv.channels == hirakudOnly.dtv.exports.channels
    &&
      map (t: t.name) exportedHirakuConsumer.services.mirakurun.tunerSettings == [
        "PT3-T1"
        "PT3-T2"
        "PT3-S1"
        "PT3-S2"
        "PT3-T3"
        "PT3-T4"
        "PT3-S3"
        "PT3-S4"
      ]
    &&
      map (t: t.types) exportedHirakuConsumer.services.mirakurun.tunerSettings
      == map (t: t.mode) hirakudOnly.dtv.exports.hirakuTuners
    && !hasService exportedHirakuConsumer "hirakud"
    && exportedHirakuConsumer.boot.extraModulePackages == [ ]
    && !exportedHirakuConsumer.services.pcscd.enable
    && builtins.all (name: !(builtins.elem name exportedHirakuConsumer.boot.kernelModules)) [
      "pt3_drv"
      "px4_drv"
      "smsdvb"
      "smsmdtv"
      "cxd2857"
      "tbs6812"
    ];

  mirakurunOnly = configOf {
    dtv.mirakurun.enable = true;
    dtv.channels = [
      {
        name = "example";
        type = "GR";
        channel = "13";
      }
    ];
    dtv.tuners = [
      {
        name = "local";
        driver = "command";
        mode = [ "GR" ];
        command = [
          "/bin/true"
          "<channel>"
        ];
      }
    ];
  };
  mirakurunOnlyContract =
    !hasService mirakurunOnly "hirakud"
    && mirakurunOnly.services.mirakurun.channelSettings == mirakurunOnly.dtv.channels
    && map (t: t.name) mirakurunOnly.services.mirakurun.tunerSettings == [ "local" ]
    && map (t: t.name) mirakurunOnly.dtv.exports.mirakurunTuners == [ "local" ];

  compactPt3 = configOf {
    dtv.mirakurun.enable = true;
    dtv.tuners = [
      { driver = "pt3"; }
      { driver = "pt3"; }
    ];
  };
  compactPt3Contract =
    map (t: t.name) compactPt3.services.mirakurun.tunerSettings == [
      "PT3-T1"
      "PT3-T2"
      "PT3-S1"
      "PT3-S2"
      "PT3-T3"
      "PT3-T4"
      "PT3-S3"
      "PT3-S4"
    ]
    &&
      map (t: t.types) compactPt3.services.mirakurun.tunerSettings == [
        [ "GR" ]
        [ "GR" ]
        [
          "BS"
          "CS"
        ]
        [
          "BS"
          "CS"
        ]
        [ "GR" ]
        [ "GR" ]
        [
          "BS"
          "CS"
        ]
        [
          "BS"
          "CS"
        ]
      ]
    &&
      map (t: t.checkDevicePath) compactPt3.services.mirakurun.tunerSettings == [
        "/dev/pt3video2"
        "/dev/pt3video3"
        "/dev/pt3video0"
        "/dev/pt3video1"
        "/dev/pt3video6"
        "/dev/pt3video7"
        "/dev/pt3video4"
        "/dev/pt3video5"
      ];

  explicitPt3 = configOf {
    dtv.mirakurun.enable = true;
    dtv.tuners = [
      {
        name = "single";
        driver = "pt3";
        mode = [ "GR" ];
        device = "/dev/pt3video0";
      }
    ];
  };
  explicitPt3Contract =
    map (t: t.name) explicitPt3.services.mirakurun.tunerSettings == [ "single" ]
    && map (t: t.types) explicitPt3.services.mirakurun.tunerSettings == [ [ "GR" ] ]
    && map (t: t.checkDevicePath) explicitPt3.services.mirakurun.tunerSettings == [ "/dev/pt3video0" ];

  unnamedPt3 = configOf {
    dtv.mirakurun.enable = true;
    dtv.tuners = [
      {
        name = "";
        driver = "pt3";
        mode = [ "GR" ];
        device = "/dev/pt3video0";
      }
      {
        driver = "pt3";
        mode = [ "GR" ];
        device = "/dev/pt3video1";
      }
      {
        driver = "pt3";
        mode = [
          "BS"
          "CS"
        ];
        device = "/dev/pt3video2";
      }
    ];
  };
  unnamedPt3Contract =
    map (t: t.name) unnamedPt3.services.mirakurun.tunerSettings == [
      "PT3-T1"
      "PT3-T2"
      "PT3-S1"
    ];

  hardwareOnly = configOf {
    dtv.mirakurun.enable = true;
    dtv.tuners = [
      {
        driver = "pt3";
        mode = [ ];
      }
    ];
  };
  hardwareOnlyContract =
    hardwareOnly.services.mirakurun.tunerSettings == [ ]
    && builtins.length hardwareOnly.boot.extraModulePackages == 1
    && builtins.elem "pt3_drv" hardwareOnly.boot.kernelModules
    && !hardwareOnly.services.pcscd.enable;

  genericCard = configOf {
    dtv.card.enable = true;
    dtv.hirakud.enable = true;
    dtv.tuners = [
      {
        driver = "pt3";
        mode = [ "GR" ];
        device = "/dev/pt3video0";
      }
    ];
  };
  genericCardContract =
    genericCard.services.pcscd.enable
    && hasNamedPackage "ccid" genericCard.services.pcscd.plugins
    && hasNamedPackage "pcsc-tools" genericCard.environment.systemPackages
    && builtins.elem "pcscd.service" genericCard.systemd.services.hirakud.wants
    && builtins.elem "pcscd.service" genericCard.systemd.services.hirakud.after;

  rw5100Card = configOf {
    dtv.card = {
      enable = true;
      rw5100Support = true;
    };
  };
  rw5100CardContract =
    rw5100Card.services.pcscd.enable
    && hasPackage rw5100Card.dtv.card.package rw5100Card.services.pcscd.plugins
    && hasPackage rw5100Card.dtv.card.package rw5100Card.environment.systemPackages
    && lib.hasInfix "ATTR{idVendor}==\"04dd\"" rw5100Card.services.udev.extraRules
    && lib.hasInfix "ATTR{idProduct}==\"9259\"" rw5100Card.services.udev.extraRules;

  cardDisabled = configOf { };
  cardDisabledContract =
    !cardDisabled.services.pcscd.enable && cardDisabled.services.pcscd.plugins == [ ];

  remoteOnly = configOf {
    dtv.mirakurun.enable = true;
    dtv.tuners = [
      {
        name = "hiraku-client";
        driver = "hiraku";
        mode = [ "GR" ];
        hiraku = {
          address = "relay.example:40773";
          secret = "test-only";
          mode = "gr";
        };
      }
      {
        name = "mirakurun-client";
        driver = "remote";
        mode = [ "BS" ];
        remote.host = "upstream.example";
      }
    ];
  };
  remoteOnlyContract =
    !hasService remoteOnly "hirakud"
    && remoteOnly.boot.extraModulePackages == [ ]
    && builtins.all (name: !(builtins.elem name remoteOnly.boot.kernelModules)) [
      "pt3_drv"
      "px4_drv"
      "smsdvb"
      "smsmdtv"
      "cxd2857"
      "tbs6812"
    ]
    && !remoteOnly.services.pcscd.enable
    && builtins.elem "network-online.target" remoteOnly.systemd.services.mirakurun.wants
    && hasPackage remoteOnly.dtv.packages.hiraku remoteOnly.systemd.services.mirakurun.path;

  disabledEntry = configOf {
    dtv.mirakurun.enable = true;
    dtv.tuners = [
      {
        enable = false;
        driver = "pt3";
        mode = [ "GR" ];
        b25 = true;
      }
      {
        enable = false;
        driver = "remote";
        mode = [ "BS" ];
      }
    ];
  };
  disabledEntryContract =
    disabledEntry.boot.extraModulePackages == [ ]
    && !(builtins.elem "pt3_drv" disabledEntry.boot.kernelModules)
    && !disabledEntry.services.pcscd.enable
    && disabledEntry.services.mirakurun.tunerSettings == [ ];

  remoteEpgstation = configOf {
    dtv.epgstation = {
      enable = true;
      settings = {
        mirakurunPath = "http://upstream.example:40772";
        epgUpdaterMode = "external";
      };
    };
  };
  remoteEpgstationContract =
    !hasService remoteEpgstation "mirakurun"
    && builtins.hasAttr "epgstation-epg-update" remoteEpgstation.systemd.services
    && !(builtins.elem "mirakurun.service" remoteEpgstation.systemd.services.epgstation-epg-update.wants)
    && !(builtins.elem "mirakurun.service" remoteEpgstation.systemd.services.epgstation-epg-update.after);

  replacementMirakurun = fakeExe "mirakurun";
  replacementRecorder = fakeExe "recpt1";
  packageReplacement = configOf {
    dtv.mirakurun = {
      enable = true;
      package = replacementMirakurun;
    };
    dtv.packages.recpt1 = replacementRecorder;
    dtv.tuners = [
      {
        name = "override";
        driver = "pt3";
        mode = [ "GR" ];
        device = "/dev/pt3video0";
      }
    ];
  };
  packageReplacementContract =
    lib.hasInfix (builtins.unsafeDiscardStringContext replacementMirakurun.outPath) packageReplacement.systemd.services.mirakurun.serviceConfig.ExecStart
    && hasPackage replacementRecorder packageReplacement.systemd.services.mirakurun.path
    && map (t: t.name) packageReplacement.services.mirakurun.tunerSettings == [ "override" ]
    && map (t: t.types) packageReplacement.services.mirakurun.tunerSettings == [ [ "GR" ] ];

  helperContract =
    self.lib.mkHirakuTuners {
      address = "relay.example:40773";
      secret = "test-only";
      namePrefix = "remote-";
      tuners = [
        {
          name = "gr";
          mode = [ "GR" ];
          hiraku = {
            mode = "gr";
            modeBS4K = null;
          };
        }
      ];
    } == [
      {
        driver = "hiraku";
        name = "remote-gr";
        mode = [ "GR" ];
        hiraku = {
          address = "relay.example:40773";
          secret = "test-only";
          mode = "gr";
          modeBS4K = null;
        };
      }
    ]
    &&
      self.lib.mkRemoteTuners {
        host = "upstream.example";
        tuners = [
          {
            name = "bs";
            mode = [ "BS" ];
          }
        ];
      } == [
        {
          driver = "remote";
          name = "bs";
          mode = [ "BS" ];
          remote = {
            host = "upstream.example";
            port = 40772;
            decoder = true;
          };
        }
      ];

  invalidContract =
    assertionFails "dtv.tuners names must be unique." {
      dtv.hirakud.enable = true;
      dtv.tuners = [
        {
          name = "duplicate";
          driver = "command";
          mode = [ "GR" ];
          command = [ "/bin/true" ];
        }
        {
          name = "duplicate";
          driver = "command";
          mode = [ "BS" ];
          command = [ "/bin/true" ];
        }
      ];
    }
    && assertionFails "Hiraku mode names must be unique." {
      dtv.hirakud.enable = true;
      dtv.tuners = [
        {
          name = "one";
          driver = "pt3";
          mode = [ "GR" ];
          device = "/dev/pt3video0";
          serve.mode = "same";
        }
        {
          name = "two";
          driver = "pt3";
          mode = [ "GR" ];
          device = "/dev/pt3video1";
          serve.mode = "same";
        }
      ];
    }
    && assertionFails "A local capture tuner requires device or command." {
      dtv.tuners = [
        {
          driver = "pt3";
          mode = [ "GR" ];
        }
      ];
    }
    && assertionFails "Non-PT3 tuners require explicit mode; use [] for hardware only." {
      dtv.tuners = [
        {
          driver = "tbs6812";
        }
      ];
    }
    && assertionFails "A remote tuner requires remote.host." {
      dtv.tuners = [
        {
          driver = "remote";
          mode = [ "GR" ];
        }
      ];
    }
    && assertionFails "A Hiraku tuner requires hiraku.address, secret and mode." {
      dtv.tuners = [
        {
          driver = "hiraku";
          mode = [ "GR" ];
          hiraku = {
            address = "relay.example:40773";
            mode = "gr";
          };
        }
      ];
    };

  require = name: value: if value then true else throw "dtv check failed: ${name}";
  contract =
    require "hirakud-only role" hirakudOnlyContract
    && require "exported Hiraku consumer" exportedHirakuConsumerContract
    && require "mirakurun-only role" mirakurunOnlyContract
    && require "compact PT3 cards" compactPt3Contract
    && require "explicit PT3 tuner" explicitPt3Contract
    && require "unnamed PT3 tuners" unnamedPt3Contract
    && require "hardware-only tuner" hardwareOnlyContract
    && require "generic card" genericCardContract
    && require "RW5100 card" rw5100CardContract
    && require "disabled card" cardDisabledContract
    && require "remote-only clients" remoteOnlyContract
    && require "disabled tuner entries" disabledEntryContract
    && require "remote EPGStation" remoteEpgstationContract
    && require "package replacement" packageReplacementContract
    && require "export helpers" helperContract
    && require "invalid inventories" invalidContract;
in
{
  dtv =
    assert contract;
    pkgs.runCommand "jodtv-packages-dtv" { } "touch $out";
}
