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
  desktopPkgs = import nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [ self.overlays.default ];
    config.allowUnfreePredicate = package: lib.getName package == "edcb-wine";
  };
  # Build the real archive and launcher on the check host, without executing
  # Windows binaries or requiring Wine on macOS. Process behavior is tested
  # separately below with a Wine substitute.
  desktopCli =
    (desktopPkgs.edcb-wine.override { winePackage = pkgs.emptyDirectory; }).overrideAttrs
      (old: {
        meta = old.meta // {
          platforms = [ pkgs.stdenv.hostPlatform.system ];
        };
      });
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
    assert enabled.services.edcb-wine.package.meta.mainProgram == "edcb-wine";
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
  edcb-wine-desktop = pkgs.runCommand "edcb-wine-desktop" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python ${../scripts/test_edcb_launcher.py} ${../pkgs/edcb-wine/run.py} ${../modules/edcb-wine/init-runtime.py} "$TMPDIR/edcb-desktop-tests"
    unset DISPLAY
    ${desktopCli}/bin/edcb-wine --help > help.txt
    grep -q 'scan-gr' help.txt
    if ${desktopCli}/bin/edcb-wine --state-dir "$TMPDIR/uncreated-state" > output.txt 2>&1; then
      echo "Missing desktop should have failed"
      exit 1
    fi
    cat output.txt
    grep -q 'EDCB needs an X11 desktop' output.txt
    test ! -e "$TMPDIR/uncreated-state"
    # A profile symlink must still resolve the bundle beside the real launcher.
    mkdir profile
    ln -s ${desktopCli}/bin/edcb-wine profile/edcb-wine
    profile/edcb-wine --help > profile-help.txt
    cmp help.txt profile-help.txt
    touch "$out"
  '';
}
