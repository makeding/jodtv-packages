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
    version = "0.15.0-dev-unstable-2026-11-26";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "2d3ed8342def8171780c944b965f725f842d5ff2";
      hash = "sha256-n0PaXqpHV90OidaJmBsp8oOc6kYfroD6oA6gD7GBd08=";
    };
    yarnHash = "sha256-y3Bg9P3Kbh/Whz24YGp7rR9rtoo++d5xLbiCYPykWcw=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
