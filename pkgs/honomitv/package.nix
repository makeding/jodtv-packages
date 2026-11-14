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
    version = "0.15.0-dev-unstable-2026-11-14";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "56c2ce4f4b66b60de20d16e1a6d40989de404227";
      hash = "sha256-fk5fvPeDW/0lYwjqQiWFkjj/CSG/3gB2B1wevdHGPdk=";
    };
    yarnHash = "sha256-toRPU/rdPm/mlNIogKBDtvHOsMOgE0+YvRNSISP2eIk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
