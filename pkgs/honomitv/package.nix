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
      rev = "ee70b490cc28e2a1cad9d8bc3dc859984ba9a6ef";
      hash = "sha256-nDb+L6jei4jEPLeTJaUx8RdRDdYXpHh06szgLvBeWl4=";
    };
    yarnHash = "sha256-H1bQW/B104Tyo8S099i4NL9NDxkYvKxrgUmuU6ku8Xk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
