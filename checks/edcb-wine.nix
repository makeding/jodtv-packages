{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  systemFor =
    module:
    (lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;
          nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "edcb-wine";
        }
        module
      ];
    }).config;
  defaults = systemFor { };
  enabled = systemFor { services.edcb-wine.enable = true; };
  custom = systemFor {
    services.edcb-wine = {
      enable = true;
      stateDir = "/srv/edcb";
      recordingDir = "/srv/recordings";
      recordingInfoDir = "/srv/info";
      recordingDirectories = [ "/srv/archive" ];
      backend = {
        host = "tuner.example";
        port = 40773;
      };
      vnc = {
        listenAddress = "0.0.0.0";
        port = 5990;
      };
      openFirewall = true;
    };
  };
  loopback = systemFor {
    services.edcb-wine = {
      enable = true;
      openFirewall = true;
    };
  };
in
{
  edcb-wine-module =
    assert !defaults.services.edcb-wine.enable;
    assert !(defaults.systemd.services ? edcb-wine);
    assert enabled.services.edcb-wine.vnc.listenAddress == "127.0.0.1";
    assert enabled.networking.firewall.allowedTCPPorts == [ ];
    assert
      loopback.networking.firewall.allowedTCPPorts == [
        4510
        5510
      ];
    assert
      custom.networking.firewall.allowedTCPPorts == [
        4510
        5510
        5990
      ];
    assert
      custom.systemd.services.edcb-wine.serviceConfig.ReadWritePaths == [
        "/srv/edcb"
        "/srv/recordings"
        "/srv/info"
        "/srv/archive"
      ];
    assert
      custom.systemd.services.edcb-wine.unitConfig.RequiresMountsFor == [
        "/srv/edcb"
        "/srv/recordings"
        "/srv/info"
        "/srv/archive"
      ];
    assert builtins.all (item: item.assertion) enabled.assertions;
    assert builtins.all (item: item.assertion) custom.assertions;
    assert lib.hasSuffix "start-edcb-wine-systemd"
      custom.systemd.services.edcb-wine.serviceConfig.ExecStart;
    assert self.packages.x86_64-linux ? edcb-wine;
    assert !(self.packages.aarch64-linux ? edcb-wine);
    assert !(self.packages.aarch64-darwin ? edcb-wine);
    pkgs.runCommand "edcb-wine-module" { } "touch $out";
  edcb-wine-state = pkgs.runCommand "edcb-wine-state" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python ${../scripts/test_edcb_wine.py} ${../modules/edcb-wine/init-runtime.py} "$TMPDIR/edcb-state-tests"
    touch "$out"
  '';
  edcb-wine-script =
    pkgs.runCommand "edcb-wine-script"
      {
        defaultScript = builtins.unsafeDiscardStringContext enabled.systemd.services.edcb-wine.serviceConfig.ExecStart.text;
        customScript = builtins.unsafeDiscardStringContext custom.systemd.services.edcb-wine.serviceConfig.ExecStart.text;
        passAsFile = [
          "defaultScript"
          "customScript"
        ];
      }
      ''
        ${pkgs.bash}/bin/bash -n "$defaultScriptPath"
        ${pkgs.bash}/bin/bash -n "$customScriptPath"
        touch "$out"
      '';
}
