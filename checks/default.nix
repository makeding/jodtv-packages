{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  public = import ../pkgs {
    inherit (pkgs) callPackage;
    inputs = self.inputs;
  };
  marker = pkgs.emptyDirectory;
  recorderInputs = p: map (input: input.outPath) p.nativeBuildInputs;
  hasInput = p: input: builtins.elem input.outPath (recorderInputs p);
  injectable =
    builtins.all
      (
        name:
        hasInput public.${name} pkgs.libaribb25
        && hasInput (public.${name}.override { libaribb25 = marker; }) marker
        && !(hasInput (public.${name}.override { libaribb25 = marker; }) pkgs.libaribb25)
      )
      [
        "recpt1"
        "recdvb"
      ];
  moduleConfig =
    (nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        self.nixosModules.default
        {
          system.stateVersion = "26.05";
          # This fixture exercises the real Hiraku service definition. Its
          # pinned source has no license grant, so opt in only in this check.
          nixpkgs.config.allowUnfreePredicate = p: lib.getName p == "hiraku";
          hardware.jodtv-packages.tuners = [
            "pt3"
            "tbs6812"
          ];
          services.hirakud.enable = true;
        }
      ];
    }).config;
  moduleContract =
    builtins.length moduleConfig.boot.extraModulePackages == 2
    && builtins.all (
      p:
      builtins.any (
        flag:
        lib.hasInfix (builtins.unsafeDiscardStringContext (toString moduleConfig.boot.kernelPackages.kernel.dev)) flag
      ) p.makeFlags
    ) moduleConfig.boot.extraModulePackages
    && builtins.elem "pt3_drv" moduleConfig.boot.kernelModules
    && builtins.elem "cxd2857" moduleConfig.boot.kernelModules
    && moduleConfig.systemd.services.hirakud.serviceConfig.ExecStart != "";
in
{
  dependency-injection =
    assert injectable;
    pkgs.runCommand "jodtv-packages-dependency-injection" { } "touch $out";
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  modules =
    assert moduleContract;
    pkgs.runCommand "jodtv-packages-modules" { } "touch $out";
}
