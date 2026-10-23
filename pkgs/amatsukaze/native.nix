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
  nativeBuildInputs = [ meson ninja pkg-config python3 ];
  buildInputs = [ ffmpeg avisynthplus libjpeg_turbo libaribcaption fontconfig zlib ];
  postPatch = ''
    python - <<'PY'
    from pathlib import Path
    path = Path('meson.build')
    text = path.read_text()
    start = text.index("git = find_program('git')")
    end = text.index('# Version.h', start)
    # Archive builds have no Git metadata. The package owns the release version.
    text = text[:start] + "version_h = configure_file(input: 'Version.h.in', output: 'Version.h', copy: true)\n" + text[end:]
    # Keep one dynamically linked copy of font/rendering dependencies in the
    # process rather than embedding a second C++/FFmpeg dependency closure.
    start = text.index("aribcaption_pkg_dep =")
    end = text.index('# glibc', start)
    text = text[:start] + "aribcaption_dep = dependency('libaribcaption', required: true)\n\n" + text[end:]
    text = text.replace("dependency('zlib', required : true, static : true)", "dependency('zlib', required : true)")
    path.write_text(text)
    Path('Version.h.in').write_text('#define AMATSUKAZE_VERSION "${version}"\n#define AMATSUKAZE_PRODUCTVERSION ${lib.replaceStrings [ "." ] [ "," ] version}\n')
    PY
  '';
  doCheck = true;
  postInstall = ''
    # --loadv2 chooses this filename; both paths must use the selected libav.
    ln -s libAmatsukaze.so "$out/lib/libAmatsukaze2.so"
  '';
  passthru = { inherit ffmpeg; compilerRuntime = stdenv.cc.cc.lib; };
  meta = {
    description = "Amatsukaze native engines rebuilt against the selected FFmpeg";
    homepage = "https://github.com/rigaya/Amatsukaze";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    maintainers = [ lib.maintainers.huggy ];
  };
}
