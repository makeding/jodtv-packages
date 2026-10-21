{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  pcsclite,
}:

stdenv.mkDerivation {
  pname = "libaribb25";
  version = "1fec6425319f38da4d6c3c2871b937e396dff369";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "libaribb25";
    rev = "1fec6425319f38da4d6c3c2871b937e396dff369";
    hash = "sha256-VwehXlhMJjWWyEooB95bTxXXB/uZIxzuksslnvsrgYY=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    pcsclite
  ];

  enableParallelBuilding = true;
  CXXFLAGS = "-std=c++20";
  meta = {
    description = "Cross-platform ARIB STD-B1 and ARIB STD-B25 decoder library";
    homepage = "https://github.com/tsukumijima/libaribb25";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
    maintainers = [ lib.maintainers.huggy ];
    replace = [ "aribb25" ];
  };
}
