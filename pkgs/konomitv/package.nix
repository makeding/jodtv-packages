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
    version = "0.15.0-dev-unstable-2026-11-06";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "b5c58ee57e52d2d69f8923b6d3e9d27cc29f1f96";
      hash = "sha256-Y/aIO0kprKc/rcMwD4/lqe3+5LgmYHiDYiuhaC8Yi6o=";
    };
    yarnHash = "sha256-XvHYRbIQVw4DDRGzPp/XZavbJjxw49Tzb53P+5sIeH4=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
