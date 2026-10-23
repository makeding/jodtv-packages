{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  configOf =
    encoder:
    (lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.packages
        self.nixosModules.honomitv
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;
          services.honomitv = {
            enable = true;
            inherit encoder;
          };
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [ (_: _: { inherit (pkgs) fetchFromGitHub fetchurl; }) ];
        }
      ];
    }).config;
  software = configOf "FFmpeg";
  qsv = configOf "QSVEncC";
  nvenc = configOf "NVEncC";
  softwarePackage = software.services.honomitv.package;
  qsvPackage = qsv.services.honomitv.package;
  nvencPackage = nvenc.services.honomitv.package;
  referenced =
    package: dependency:
    lib.hasInfix (builtins.unsafeDiscardStringContext dependency.outPath) (
      builtins.unsafeDiscardStringContext package.postPatch
    );
in
{
  honomitv-encoder-selection =
    assert softwarePackage.nvenccForHost == null;
    assert softwarePackage.qsvenccForHost == null;
    assert qsvPackage.nvenccForHost == null;
    assert qsvPackage.qsvenccForHost != null;
    assert nvencPackage.qsvenccForHost == null;
    assert nvencPackage.nvenccForHost != null;
    assert builtins.elem "NVEncC" qsvPackage.uncheckedTools;
    assert !(builtins.elem "QSVEncC" qsvPackage.uncheckedTools);
    assert builtins.elem "QSVEncC" nvencPackage.uncheckedTools;
    assert !(builtins.elem "NVEncC" nvencPackage.uncheckedTools);
    assert builtins.all (name: builtins.elem name softwarePackage.uncheckedTools) [
      "QSVEncC"
      "NVEncC"
    ];
    assert referenced qsvPackage qsvPackage.qsvenccForHost;
    assert referenced nvencPackage nvencPackage.nvenccForHost;
    assert !(referenced qsvPackage nvencPackage.nvenccForHost);
    assert !(referenced nvencPackage qsvPackage.qsvenccForHost);
    assert !(software.systemd.services.honomitv.environment ? ONEVPL_SEARCH_PATH);
    assert !(nvenc.systemd.services.honomitv.environment ? LIBVA_DRIVER_NAME);
    assert qsv.systemd.services.honomitv.environment.LIBVA_DRIVER_NAME == "iHD";
    assert lib.hasInfix "intel-media-sdk" qsv.systemd.services.honomitv.environment.ONEVPL_SEARCH_PATH;
    assert builtins.all (c: builtins.all (a: a.assertion) c.assertions) [
      software
      qsv
      nvenc
    ];
    pkgs.runCommand "honomitv-encoder-selection" { } "touch $out";
}
