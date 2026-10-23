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
      rev = "0126a9b91b2f931c9ddbc1a8f033cf4049cc4e11";
      hash = "sha256-Mg7HFejdvrPzCHPOc9LL/6CQMCN6oCcMzZ0k5L+XCeU=";
    };
    yarnHash = "sha256-3fMgAeiZOF6J4JmtcFj1XMhc7anEx6NJPXzLcy8U+Rw=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
