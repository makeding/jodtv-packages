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
      rev = "e635fe9165ca680cc80f24ec5c409c23ee2f2af3";
      hash = "sha256-vZkCS6cp1YIXkbyRZZBX5YFr0xW4ttu7Pc/DpC5sNuo=";
    };
    yarnHash = "sha256-3fMgAeiZOF6J4JmtcFj1XMhc7anEx6NJPXzLcy8U+Rw=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
