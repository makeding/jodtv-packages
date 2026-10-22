{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  python3,
  tsduck,
  ffmpeg,
  hiraku,
  libass,
  opencl-headers,
  ocl-icd,
}:

let
  tsduckRuntime =
    if stdenv.isDarwin then
      tsduck.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace scripts/make-config.sh \
            --replace-fail 'CXXFLAGS_WARNINGS="-Werror"' 'CXXFLAGS_WARNINGS="-Wall"'
        '';
      })
    else
      tsduck;
in
stdenv.mkDerivation rec {
  pname = "tsreplace";
  version = "0.20-unstable-2026-09-05";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = pname;
    rev = "014c8d7e0b3da8fd415ebff5ec99796c6b867dbf";
    hash = "sha256-0aoXFe8CSzwjM/M1TGnGTBmVJzeAHA/v1HrmFklwSK8=";
  };

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    python3
  ];

  buildInputs = [
    ffmpeg
    ffmpeg.dev
    libass
    libass.dev
    opencl-headers
    ocl-icd
  ]
  ++ lib.optionals stdenv.isDarwin [
    # On macOS, pthread is provided by the system
  ];

  # Let stdenv handle the standard phases
  configureScript = "./configure";

  configureFlags = [
    "--prefix=${placeholder "out"}"
    "--extra-cxxflags=-I${opencl-headers}/include"
  ];

  postInstall = ''
    install -Dm755 scripts/trim_directory.py \
      $out/bin/tsreplace-trim-directory
    install -Dm644 scripts/ts_type_d.py \
      $out/bin/ts_type_d.py
    patchShebangs $out/bin/tsreplace-trim-directory
    wrapProgram $out/bin/tsreplace-trim-directory \
      --add-flags "--tsreplace $out/bin/tsreplace" \
      --prefix PATH : ${
        lib.makeBinPath [
          tsduckRuntime
          ffmpeg
          hiraku
        ]
      }
  '';

  # Help pkg-config find libraries
  env.PKG_CONFIG_PATH = lib.makeSearchPath "lib/pkgconfig" [
    ffmpeg.dev
    libass.dev
  ];

  meta = with lib; {
    description = "tsの映像部分のみの置き換えを行ってサイズ圧縮を図るツールです。";
    longDescription = ''
      tsreplace is a tool designed to replace only the video portion of a TS
      (Transport Stream) file to help compress its size. It supports hardware
      encoders like Intel QSV and NVENC, as well as software encoders like
      x264 and x265.
    '';
    homepage = "https://github.com/makeding/tsreplace";
    mainProgram = "tsreplace";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = [ lib.maintainers.huggy ];
  };
}
