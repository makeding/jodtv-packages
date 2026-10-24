{
  lib,
  stdenv,
  meson,
  ninja,
  pkg-config,
  python3,
  ffmpeg,
  avisynthplus,
  libjpeg_turbo,
  libaribcaption,
  fontconfig,
  zlib,
  version,
  src,
}:
stdenv.mkDerivation {
  pname = "amatsukaze-native";
  inherit version src;
  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    python3
  ];
  buildInputs = [
    ffmpeg
    avisynthplus
    libjpeg_turbo
    libaribcaption
    fontconfig
    zlib
  ];
  postPatch = ''
    python - <<'PY'
    from pathlib import Path
    path = Path('meson.build')
    text = path.read_text()
    # Generated headers live in Meson's build root; upstream targets use cpp_args.
    text = text.replace("cpp_args = []", "cpp_args = ['-I' + meson.current_build_dir()]", 1)
    start = text.index("git = find_program('git')")
    end = text.index('# Version.h', start)
    # Archive builds have no Git metadata. The package owns the release version.
    text = text[:start] + "version_h = configure_file(input: 'Version.h.in', output: 'Version.h', copy: true)\n" + text[end:]
    # Keep one dynamically linked copy of font/rendering dependencies in the
    # process rather than embedding a second C++/FFmpeg dependency closure.
    start = text.index("aribcaption_pkg_dep =")
    end = text.index('# glibc', start)
    text = text[:start] + "aribcaption_dep = declare_dependency(dependencies: [\n  dependency('libaribcaption', required: true),\n  dependency('fontconfig', required: true),\n])\n\n" + text[end:]
    text = text.replace("dependency('zlib', required : true, static : true)", "dependency('zlib', required : true)")
    path.write_text(text)
    # FFmpeg 9 removed the legacy FF_PROFILE_* aliases; keep the pinned
    # upstream source compatible with current libavcodec headers.
    source = Path('Amatsukaze/AudioTrackConverter.cpp')
    source_text = source.read_text()
    source.write_text(source_text.replace('FF_PROFILE_AAC_LOW', 'AV_PROFILE_AAC_LOW'))
    Path('Version.h.in').write_text('#define AMATSUKAZE_VERSION "${version}"\n#define AMATSUKAZE_PRODUCTVERSION ${
      lib.replaceStrings [ "." ] [ "," ] version
    }\n')
    PY
  '';
  doCheck = true;
  postInstall = ''
    # --loadv2 chooses this filename; both paths must use the selected libav.
    ln -s libAmatsukaze.so "$out/lib/libAmatsukaze2.so"
    # The CLI and logo tool dlopen beside their executable, not from lib/.
    for library in libAmatsukaze.so libAmatsukaze2.so; do
      ln -s ../lib/$library "$out/bin/$library"
    done
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # No input prints usage and exits 1. This still loads the selected library
    # and resolves its exported CLI symbol through the actual installed path.
    for mode in default v2; do
      args=()
      if [ "$mode" = v2 ]; then args+=(--loadv2); fi
      status=0
      "$out/bin/AmatsukazeCLI" "''${args[@]}" > "$mode.log" 2>&1 || status=$?
      cat "$mode.log"
      test "$status" = 1
      grep -q -- '--input' "$mode.log"
    done
    runHook postInstallCheck
  '';
  passthru = {
    inherit ffmpeg;
    compilerRuntime = stdenv.cc.cc.lib;
  };
  meta = {
    description = "Amatsukaze native engines rebuilt against the selected FFmpeg";
    homepage = "https://github.com/rigaya/Amatsukaze";
    license = lib.licenses.gpl2Plus;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "AmatsukazeCLI";
    maintainers = [ lib.maintainers.huggy ];
  };
}
