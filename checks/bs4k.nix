{ self, nixpkgs, pkgs }:
let
  lib = nixpkgs.lib;
  systemOf = module: lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ self.nixosModules.default {
      system.stateVersion = "26.05";
      boot.isContainer = true;
      nixpkgs.config.allowUnfree = true;
      # Source-only IFDs must use a native fetcher when evaluating Linux on macOS.
      nixpkgs.overlays = [ (_: _: {
        inherit (pkgs) fetchFromGitHub fetchurl;
      }) ];
    } module ];
  };
  normal = systemOf { };
  manual = systemOf { dtv.bs4k = true; };
  tuner = { driver = "remote"; mode = [ "BS4K" ]; remote.host = "tuner.example"; };
  automatic = systemOf { dtv.tuners = [ tuner ]; };
  disabled = systemOf { dtv.tuners = [ (tuner // { enable = false; }) ]; };
  forbidden = systemOf { dtv.bs4k = false; dtv.tuners = [ tuner ]; };
  selected = manual.pkgs;
  ffmpeg = selected.ffmpeg-libaribtlv;
  hasInput = p: input: builtins.elem input.outPath (map (p: p.outPath) p.buildInputs);
  hasReference = text: p: lib.hasInfix (builtins.unsafeDiscardStringContext p.outPath)
    (builtins.unsafeDiscardStringContext text);
in
{
  bs4k-selection =
    assert !normal.config.dtv.bs4k;
    assert manual.config.dtv.bs4k;
    assert automatic.config.dtv.bs4k;
    assert !disabled.config.dtv.bs4k;
    assert !(builtins.all (a: a.assertion) forbidden.config.assertions);
    assert normal.pkgs.tsreplace.drvPath == disabled.pkgs.tsreplace.drvPath;
    assert !normal.pkgs.nvencc.fromSource;
    assert !normal.pkgs.amatsukaze.bs4k;
    assert selected.tsreplace.drvPath == automatic.pkgs.tsreplace.drvPath;
    assert hasInput selected.tsreplace ffmpeg;
    assert hasInput selected.qsvencc ffmpeg;
    assert selected.nvencc.fromSource;
    assert hasInput selected.nvencc ffmpeg;
    assert selected.amatsukaze.bs4k;
    assert hasInput selected.amatsukaze.sourceBuild ffmpeg;
    assert builtins.elem ffmpeg.outPath (map (p: p.outPath) selected.amatsukaze.mp4box.nativeBuildInputs);
    assert selected.amatsukaze.tsreplace.drvPath == selected.tsreplace.drvPath;
    assert builtins.all (name:
      hasInput selected.${name} ffmpeg
      && selected.${name}.nvenccForHost.drvPath == selected.nvencc.drvPath
      && hasReference selected.${name}.postPatch selected.qsvencc
      && hasReference selected.${name}.postPatch ffmpeg
      && hasInput selected.${name}.pythonSet.av ffmpeg
      && lib.hasSuffix ".tar.gz" selected.${name}.pythonSet.av.src.url
    ) [ "honomitv" "konomitv" ];
    assert builtins.all (name: hasReference selected.${name}.postInstall ffmpeg)
      [ "epgstation-h" "epgstation-upstream" ];
    assert manual.config.services.epgstation.package.drvPath == selected.epgstation-h.drvPath;
    assert manual.config.services.honomitv.package.drvPath == selected.honomitv.drvPath;
    assert manual.config.services.amatsukaze.package.drvPath == selected.amatsukaze.drvPath;
    pkgs.runCommand "bs4k-dependency-selection" { } "touch $out";
}
