{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  systemOf =
    module:
    lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;
          nixpkgs.config.allowUnfree = true;
          # Source-only IFDs must use a native fetcher when evaluating Linux on macOS.
          nixpkgs.overlays = [
            (_: _: {
              inherit (pkgs) fetchFromGitHub fetchurl;
            })
          ];
        }
        module
      ];
    };
  normal = systemOf { };
  manual = systemOf { dtv.bs4k = true; };
  tuner = {
    driver = "remote";
    mode = [ "BS4K" ];
    remote.host = "tuner.example";
  };
  automatic = systemOf { dtv.tuners = [ tuner ]; };
  disabled = systemOf { dtv.tuners = [ (tuner // { enable = false; }) ]; };
  forbidden = systemOf {
    dtv.bs4k = false;
    dtv.tuners = [ tuner ];
  };
  selected = manual.pkgs;
  ffmpeg = selected.ffmpeg-libaribtlv;
  hasInput = p: input: builtins.elem (lib.getDev input).outPath (map (p: p.outPath) p.buildInputs);
  hasReference =
    text: p:
    lib.hasInfix (builtins.unsafeDiscardStringContext p.outPath) (
      builtins.unsafeDiscardStringContext text
    );
  toolPaths =
    name:
    let
      package = selected.${name};
      expected = builtins.unsafeDiscardStringContext (
        builtins.toJSON {
          FFmpeg = "${ffmpeg}/bin/ffmpeg";
          FFprobe = "${ffmpeg}/bin/ffprobe";
          NVEncC = "${selected.nvencc}/bin/nvencc";
          QSVEncC = "${selected.qsvencc}/bin/qsvencc";
        }
      );
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "${name}-media-tool-paths";
      inherit (package) version src;
      nativeBuildInputs = [ pkgs.python3 ];
      # Exercise the real Linux patch body with native source tools, without
      # executing encoders or building a foreign Python/frontend closure.
      postPatch = builtins.unsafeDiscardStringContext package.postPatch;
      phases = [
        "unpackPhase"
        "patchPhase"
        "checkPhase"
        "installPhase"
      ];
      doCheck = true;
      checkPhase = ''
        python - <<'PY'
        import ast, json
        from pathlib import Path
        constants = ast.parse(Path('server/app/constants.py').read_text())
        libraries = next(n.value for n in ast.walk(constants)
                         if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name)
                            and t.id == 'LIBRARY_PATH' for t in n.targets))
        values = {key.value: value.value for key, value in zip(libraries.keys, libraries.values)
                  if isinstance(key, ast.Constant) and isinstance(value, ast.Constant)}
        for name, path in json.loads('${expected}').items():
            assert values[name] == path, (name, values.get(name))
        startup = ast.parse(Path('server/KonomiTV.py').read_text())
        skipped = [n for n in ast.walk(startup) if isinstance(n, ast.Compare)
                   and isinstance(n.left, ast.Name) and n.left.id == 'library_name'
                   and isinstance(n.ops[0], ast.In) and isinstance(n.comparators[0], ast.List)]
        lists = [ast.literal_eval(n.comparators[0]) for n in skipped]
        expected_skip = {'Akebi', 'VCEEncC', 'rkmppenc'}
        assert sum(set(names) == expected_skip for names in lists) == 1, lists
        PY
      '';
      installPhase = "touch $out";
    };
  nativeAV = name: (pkgs.${name}.override { ffmpeg-headless = pkgs.ffmpeg-libaribtlv; }).pythonSet.av;
in
{
  honomitv-media-tool-paths = toolPaths "honomitv";
  konomitv-media-tool-paths = toolPaths "konomitv";
  bs4k-pyav = pkgs.runCommand "bs4k-pyav" { } ''
    PYTHONPATH=${nativeAV "honomitv"}/${pkgs.python314.sitePackages} ${pkgs.python314.interpreter} - <<'PY'
    import av
    assert 'libaribtlv' in av.formats_available, av.library_versions
    PY
    PYTHONPATH=${nativeAV "konomitv"}/${pkgs.python313.sitePackages} ${pkgs.python313.interpreter} - <<'PY'
    import av
    assert 'libaribtlv' in av.formats_available, av.library_versions
    PY
    touch "$out"
  '';
  bs4k-selection =
    assert !normal.config.dtv.bs4k;
    assert manual.config.dtv.bs4k;
    assert ffmpeg.version == "8.1.2";
    assert builtins.elem "--enable-gray" ffmpeg.configureFlags;
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
    assert builtins.elem (lib.getDev ffmpeg).outPath (
      map (p: p.outPath) selected.amatsukaze.mp4box.nativeBuildInputs
    );
    assert selected.amatsukaze.tsreplace.drvPath == selected.tsreplace.drvPath;
    assert builtins.all
      (
        name:
        hasInput selected.${name} ffmpeg
        && selected.${name}.nvenccForHost.drvPath == selected.nvencc.drvPath
        && hasReference selected.${name}.postPatch selected.qsvencc
        && hasReference selected.${name}.postPatch ffmpeg
        && hasInput selected.${name}.pythonSet.av ffmpeg
        && lib.hasSuffix ".tar.gz" selected.${name}.pythonSet.av.src.url
      )
      [
        "honomitv"
        "konomitv"
      ];
    assert builtins.all (name: hasReference selected.${name}.postInstall ffmpeg) [
      "epgstation-h"
      "epgstation-upstream"
    ];
    assert manual.config.services.epgstation.package.drvPath == selected.epgstation-h.drvPath;
    assert manual.config.services.honomitv.package.drvPath == selected.honomitv.drvPath;
    assert manual.config.services.amatsukaze.package.drvPath == selected.amatsukaze.drvPath;
    pkgs.runCommand "bs4k-dependency-selection" { } "touch $out";
}
// lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  bs4k-native-engines =
    pkgs.runCommand "bs4k-native-engines" { nativeBuildInputs = [ pkgs.patchelf ]; }
      ''
        for binary in ${selected.qsvencc}/bin/qsvencc \
          ${selected.nvencc}/bin/.nvencc-wrapped \
          ${selected.amatsukaze.sourceBuild}/lib/libAmatsukaze.so; do
          patchelf --print-needed "$binary" | grep -q 'libavformat.so'
          patchelf --print-rpath "$binary" | grep -Fq '${lib.getLib ffmpeg}/lib'
        done
        test -s ${selected.amatsukaze}/share/amatsukaze/exe_files/MP4Box
        touch "$out"
      '';
}
