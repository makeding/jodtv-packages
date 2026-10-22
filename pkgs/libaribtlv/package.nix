{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  zlib,
}:

stdenv.mkDerivation {
  pname = "libaribtlv";
  version = "0.6.1-unstable-2026-08-28";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "libaribtlv";
    rev = "a84e5b62bf9230d3fcea21c66e62f7cc5d50a3c2";
    hash = "sha256-BNj22/icgvoH4TCSuHZt2QzkVN0W0q2GvpsXAcvdJLo=";
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
