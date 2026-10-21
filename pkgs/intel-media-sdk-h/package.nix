{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libva,
  libdrm,
  libpciaccess,
  libX11,
  libxcb,
  wayland,
  python3,
}:

stdenv.mkDerivation rec {
  pname = "intel-media-sdk-h";
  version = "23.2.2";

  src = fetchFromGitHub {
    owner = "Intel-Media-SDK";
    repo = "MediaSDK";
    rev = "intel-mediasdk-${version}";
    hash = "sha256-wno3a/ZSKvgHvZiiJ0Gq9GlrEbfHCizkrSiHD6k/Loo=";
  };

  patches = [
    ./010-fix-reproducible-build.patch
    ./020-libcttmetrics-static-only.patch
    ./030-gcc13-fix.patch
    ./040-gcc15-fix.patch
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    python3
  ];

  buildInputs = [
    libva
    libdrm
    libpciaccess
    libX11
    libxcb
    wayland
  ];

  cmakeFlags = [
    "-DBUILD_ALL=ON"
    "-DBUILD_TOOLS=ON"
    "-DCMAKE_BUILD_TYPE=None"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5.0"
    "-DENABLE_ITT=OFF"
    "-DENABLE_OPENCL=OFF"
    "-DENABLE_WAYLAND=ON"
    "-DENABLE_X11_DRI3=ON"
    "-DMFX_APPS_DIR=${placeholder "out"}/lib/mfx"
  ];

  NIX_CFLAGS_COMPILE = [
    "-DNDEBUG"
    "-ffat-lto-objects"
  ];

  # Remove samples directory as it's not needed for runtime
  postInstall = ''
    rm -rf $out/lib/mfx/samples
  '';

  meta = {
    description = "The Intel® Media SDK";
    homepage = "https://github.com/Intel-Media-SDK/MediaSDK/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = [ lib.maintainers.huggy ];
  };
}
