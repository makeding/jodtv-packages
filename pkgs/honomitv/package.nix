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
    version = "0.15.0-unstable-2026-10-28";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "cb8ba84507bd89b23ae7fcd5990706e746121d99";
      hash = "sha256-ZooK1xPFOgulz3RFPQjJuWMyeJKmZUjjSVP78L1JmRo=";
    };
    yarnHash = "sha256-P/xFg/fTfkMw03wnl1EOwN+FkXQ7mhxvN7gH+1gRmpo=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
