{ self, nixpkgs, pkgs }:
let
  lib = nixpkgs.lib;
  linux = import nixpkgs {
    system = "x86_64-linux";
    overlays = [ self.overlays.default ];
    config.allowUnfreePredicate = package: builtins.elem (lib.getName package) [ "amatsukaze" "nvencc" ];
  };
  systemFor = module: (lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ self.nixosModules.default {
      system.stateVersion = "26.05";
      boot.isContainer = true;
      nixpkgs.config.allowUnfreePredicate = package: builtins.elem (lib.getName package) [ "amatsukaze" "nvencc" ];
    } module ];
  }).config;
  defaults = systemFor { };
  enabled = systemFor { services.amatsukaze.enable = true; };
  custom = systemFor {
    services.amatsukaze = {
      enable = true;
      port = 32770;
      openFirewall = true;
      mediaDirectories = [ "/srv/recordings" "/srv/encoded" ];
      path = [ linux.nvencc ];
    };
  };
in
{
  amatsukaze-module =
    assert !defaults.services.amatsukaze.enable;
    assert !(defaults.systemd.services ? amatsukaze);
    assert enabled.networking.firewall.allowedTCPPorts == [ ];
    assert custom.networking.firewall.allowedTCPPorts == [ 32770 32771 ];
    assert custom.systemd.services.amatsukaze.serviceConfig.ReadWritePaths == [ "/srv/recordings" "/srv/encoded" ];
    assert builtins.all (item: item.assertion) custom.assertions;
    assert lib.hasInfix "'server' '-p' '32770'" custom.systemd.services.amatsukaze.serviceConfig.ExecStart;
    assert self.packages.x86_64-linux.amatsukaze.meta.mainProgram == "amatsukaze";
    assert self.packages.x86_64-linux.nvencc.meta.mainProgram == "nvencc";
    assert !(self.packages.aarch64-linux ? amatsukaze);
    assert !(self.packages.aarch64-linux ? nvencc);
    assert !(self.packages.aarch64-darwin ? amatsukaze);
    assert !(self.packages.aarch64-darwin ? nvencc);
    pkgs.runCommand "amatsukaze-module" { } "touch $out";
  amatsukaze-launcher = pkgs.runCommand "amatsukaze-launcher" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python ${../scripts/test_amatsukaze.py} ${../pkgs/amatsukaze/run.py} "$TMPDIR/amatsukaze-tests"
    touch "$out"
  '';
}
