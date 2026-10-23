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
    version = "0.14.1-unstable-2026-10-22";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "b0fbc837cf74474dced7e815148b4804a5325b7d";
      hash = "sha256-xjrA5TYZ6bu5M5+UHKqUP6z8B1MM1ZHLJZkJS57sVSk=";
    };
    yarnHash = "sha256-cfTe1kENLpRxNW+NSwg554LnYlUPQ2/EPRhUrrYXUIk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
