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
callPackage ../honomitv/build.nix (
  builtins.removeAttrs args [
    "fetchFromGitHub"
    "python313"
  ]
  // {
    inherit
      pyproject-nix
      uv2nix
      pyproject-build-systems
      pythonInterpreter
      ;
    pname = "konomitv";
    version = "0.15.0-dev-unstable-2026-11-14";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "687b904bb0a2cbb329596fd7b0368c09afe19a6c";
      hash = "sha256-59S9R2zPGFw/b8KvdfXUZt4eMqcMNI+0xotbMedz3A8=";
    };
    yarnHash = "sha256-XvHYRbIQVw4DDRGzPp/XZavbJjxw49Tzb53P+5sIeH4=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
