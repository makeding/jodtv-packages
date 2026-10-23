args@{
  callPackage,
  fetchFromGitHub,
  python314,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  pythonInterpreter ? python314,
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
    version = "0.14.1-unstable-2026-10-23";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "2d3da56bbde1171ea8ea86238b3b6d68bfa64ecc";
      hash = "sha256-hfBxo8O4JNhWFg3yx7QeKjWp6k6uCavBFH1ONeTI67Y=";
    };
    yarnHash = "sha256-H1bQW/B104Tyo8S099i4NL9NDxkYvKxrgUmuU6ku8Xk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
