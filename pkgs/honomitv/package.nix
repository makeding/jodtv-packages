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
      rev = "2eeb619af9ec78defe38f4095f5018f269fb6ad9";
      hash = "sha256-nypIpWezMNZo8XLcrLlTw9OrE3QY2m1SYk2HxEiHFDM=";
    };
    yarnHash = "sha256-cfTe1kENLpRxNW+NSwg554LnYlUPQ2/EPRhUrrYXUIk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
