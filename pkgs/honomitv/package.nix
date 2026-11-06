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
    version = "0.15.0-dev-unstable-2026-11-06";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "697c5482472a1df2a90089294c98d7e7cb0f2769";
      hash = "sha256-Vq01pUwP43cS2VZ/CoQ1DzGx9Wdp44E0wuiljkFBCeE=";
    };
    yarnHash = "sha256-toRPU/rdPm/mlNIogKBDtvHOsMOgE0+YvRNSISP2eIk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
