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
    version = "0.15.0-dev-unstable-2026-11-18";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "c5745f29419f2b5a693ef39e944f6e4558155366";
      hash = "sha256-tpWUMtAO59gBcahqRcyAoAXtNqzX/dfqYkcToTK24iQ=";
    };
    yarnHash = "sha256-toRPU/rdPm/mlNIogKBDtvHOsMOgE0+YvRNSISP2eIk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
