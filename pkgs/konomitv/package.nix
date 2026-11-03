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
    version = "0.15.0-dev-unstable-2026-11-03";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "11b49e4c9af5af2d51dc4088bb1354ed388b1a49";
      hash = "sha256-oimmQVTQicAY1z5si78frC/PANvuVIc/3q02HDu4wj8=";
    };
    yarnHash = "sha256-hus/F92WpQ6JAfGRKtDNBhFqNuRWdemGBzPKxpzbtIg=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
