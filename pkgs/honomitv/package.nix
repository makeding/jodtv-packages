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
    version = "0.15.0-dev-unstable-2026-10-30";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "331fb954a0ad31f188c90ff5bf71afe82b6a0278";
      hash = "sha256-MrBgIx+kV7sKy7lOQB465ZEbRlRukcJpplRvQTkaM2E=";
    };
    yarnHash = "sha256-5i7dFULEroG8t9TVS31oIIx1wRZZq0zX7PXrNe3EHnk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
