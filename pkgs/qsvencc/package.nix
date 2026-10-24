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
  libx11,
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
  version = "8.35";

  src = fetchFromGitHub {
    owner = "rigaya";
    repo = "QSVEnc";
    rev = version;
    hash = "sha256-+HDXhsrSZasjTBVeGKoorLcHq2E8CVXIBiW66nnFCBY=";
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
    libx11
    ffmpeg
    libass
    intel-media-driver
    libvpl
    libdovi
    hdr10plus
    opencl-headers
  ];

  # CMake is needed by Meson's bundled oneVPL build, not as the top-level driver.
  dontUseCmakeConfigure = true;
  enableParallelBuilding = true;

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
