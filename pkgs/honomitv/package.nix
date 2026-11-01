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
    version = "0.15.0-dev-unstable-2026-11-01";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "9ef4c34977590cb8e4ff7bf94cd8bf0e2ddee0d8";
      hash = "sha256-BOLCmYrI6shoahwm5H1qsgi5zScIBLFOcB4RodzC8bA=";
    };
    yarnHash = "sha256-5i7dFULEroG8t9TVS31oIIx1wRZZq0zX7PXrNe3EHnk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
