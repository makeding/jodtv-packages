args@{
  callPackage,
  fetchFromGitHub,
  python313,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  pythonInterpreter ? python313,
  ...
}:
callPackage ./build.nix (
  builtins.removeAttrs args [ "fetchFromGitHub" ]
  // {
    inherit
      pyproject-nix
      uv2nix
      pyproject-build-systems
      pythonInterpreter
      ;
    pname = "honomitv";
    generateLogos = true;
    version = "0.15.0-dev-unstable-2026-11-23";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "52b2527c38cb5ec333b2d42bccd99a72883f3abd";
      hash = "sha256-y49awdXIjVtJptqHM1e99Bshmxn34MzvurlZzVtYmbo=";
    };
    yarnHash = "sha256-toRPU/rdPm/mlNIogKBDtvHOsMOgE0+YvRNSISP2eIk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
