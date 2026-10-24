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
    version = "0.14.1-unstable-2026-10-24";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "6468fe40bbc72224066837edaefb0963d7deb4fd";
      hash = "sha256-6LtrsiLCBflWS2dSJhJv6WU05CLpYwYiM5RJkLVyqrI=";
    };
    yarnHash = "sha256-H1bQW/B104Tyo8S099i4NL9NDxkYvKxrgUmuU6ku8Xk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
