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
    version = "0.15.0-dev-unstable-2026-10-29";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "0cf34f9f0c2194ce893b0a2265e523a18e0e2282";
      hash = "sha256-bKWbs3LZSE6PXQNYFQfVnwpgmr0+FEmy3C4fX+7sZi0=";
    };
    yarnHash = "sha256-P/xFg/fTfkMw03wnl1EOwN+FkXQ7mhxvN7gH+1gRmpo=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
