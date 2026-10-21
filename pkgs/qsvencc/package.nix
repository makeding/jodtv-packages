{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  meson,
  ninja,
  pkg-config,
  rustc,
  cargo,
  cargo-c,
  libva,
  libdrm,
  ffmpeg,
  libass,
  intel-media-driver,
  libvpl,
  libdovi,
  hdr10plus,
  opencl-headers,
  nasm,
}:

stdenv.mkDerivation rec {
  pname = "qsvencc";
  version = "8.34";

  src = fetchFromGitHub {
    owner = "rigaya";
    repo = "QSVEnc";
    rev = version;
    hash = "sha256-XuhHm3/g8G3xLQZV00iCg3XQOfPFxo3zgzHGZT86Iow=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    meson
    ninja
    pkg-config
    rustc
    cargo
    cargo-c
    nasm
  ];

  buildInputs = [
    libva
    libdrm
    ffmpeg
    libass
    intel-media-driver
    libvpl
    libdovi
    hdr10plus
    opencl-headers
  ];

  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail \
        "version: run_command('git', 'describe', '--tags', '--abbrev=0', check: true).stdout().strip()," \
        "version: '${version}',"
  '';

  mesonFlags = [
    "-Denable_vapoursynth=false"
    "-Denable_avisynth=false"
    "-Denable_openvino=false"
    "-Dopencl_headers=${opencl-headers}/include"
  ];

  meta = with lib; {
    description = "QSVによる高速エンコードの性能実験";
    homepage = "https://github.com/rigaya/QSVEnc";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
