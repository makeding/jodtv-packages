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
    version = "0.15.0-dev-unstable-2026-11-05";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "941d5a24ba6f5dbddab4a9bebed6eb0a7edf71c8";
      hash = "sha256-ccgP515n5436XoWuBoSfcFq0ljR4HzrJdteujvmwJ+s=";
    };
    yarnHash = "sha256-XvHYRbIQVw4DDRGzPp/XZavbJjxw49Tzb53P+5sIeH4=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
