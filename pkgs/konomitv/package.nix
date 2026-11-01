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
    version = "0.15.0-dev-unstable-2026-11-01";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "ed4e4b8d5c1b2f28d3e1baff5baf10506c6a9c74";
      hash = "sha256-zXvZlrWyvwt9isA+dGj+My7FcNse8I/+kCCK6iIO61I=";
    };
    yarnHash = "sha256-hus/F92WpQ6JAfGRKtDNBhFqNuRWdemGBzPKxpzbtIg=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
