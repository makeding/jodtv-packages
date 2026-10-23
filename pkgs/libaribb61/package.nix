{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  asio,
  pcsclite,
}:

stdenv.mkDerivation {
  pname = "libaribb61";
  version = "0.1.0-unstable-2026-10-23";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "libaribb61";
    rev = "36989999abb397aa227e646852341536fafa64a2";
    hash = "sha256-Le0CTrKWAtGf4uOQWRoaLnzslMeNXxzPEboKab7tYX4=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [ asio ] ++ lib.optionals stdenv.hostPlatform.isLinux [ pcsclite ];
  # Nix supplies absolute GNUInstallDirs paths; avoid prefixing them twice.
  postPatch = ''
    substituteInPlace libaribb61.pc.in \
      --replace-fail 'libdir=''${prefix}/@CMAKE_INSTALL_LIBDIR@' \
        'libdir=@CMAKE_INSTALL_FULL_LIBDIR@' \
      --replace-fail 'includedir=''${prefix}/@CMAKE_INSTALL_INCLUDEDIR@' \
        'includedir=@CMAKE_INSTALL_FULL_INCLUDEDIR@'
  '';
  cmakeFlags = [ "-DBUILD_TESTING=ON" ];
  doCheck = true;

  # Exercise the installed headers, pkg-config metadata and shared library together.
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    export PKG_CONFIG_PATH="$out/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    test "$(pkg-config --modversion libaribb61)" = 0.1.0
    $CC $(pkg-config --cflags libaribb61) "$src/tests/api_test.c" \
      -o installed-api-test $(pkg-config --libs libaribb61)
    ./installed-api-test
    runHook postInstallCheck
  '';

  postInstall = ''
    install -Dm644 "$src/COPYING" "$out/share/licenses/libaribb61/COPYING"
    install -Dm644 "$src/LICENSE.dantto4k" "$out/share/licenses/libaribb61/LICENSE.dantto4k"
  '';

  meta = {
    description = "Streaming ARIB STD-B61 ACAS MMT/TLV descrambling library";
    homepage = "https://github.com/makeding/libaribb61";
    license = [
      lib.licenses.gpl3Only
      lib.licenses.asl20
    ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = [ lib.maintainers.huggy ];
  };
}
