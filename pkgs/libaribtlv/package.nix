{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  zlib,
}:

stdenv.mkDerivation {
  pname = "libaribtlv";
  version = "0.6.1-unstable-2026-10-23";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "libaribtlv";
    rev = "f4a603b37cbaf5c93ed2e5a133293bacdfca70ad";
    hash = "sha256-cgNgtnV3YI6xL2tuGJCBiJhaZeJO2MoZEoEORpqZ8BU=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ zlib ];

  postPatch = ''
    substituteInPlace cmake/libaribtlv.pc.in \
      --replace-fail 'includedir=''${prefix}/@CMAKE_INSTALL_INCLUDEDIR@' \
        'includedir=@CMAKE_INSTALL_FULL_INCLUDEDIR@'
  '';

  doCheck = true;

  meta = {
    description = "ARIB MMT/TLV demuxing library";
    homepage = "https://github.com/makeding/libaribtlv";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.huggy ];
  };
}
