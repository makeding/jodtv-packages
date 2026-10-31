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
    version = "0.15.0-dev-unstable-2026-10-31";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "9524b7e3e4c8d563ea17edc6cc0a9d23f91b3e21";
      hash = "sha256-F+Yl9wYBd/0EA+iKm7OUajUIMb4Qm9kq+wc3nduEvLY=";
    };
    yarnHash = "sha256-5i7dFULEroG8t9TVS31oIIx1wRZZq0zX7PXrNe3EHnk=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
