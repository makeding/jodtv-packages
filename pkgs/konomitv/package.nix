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
    version = "0.15.0-unstable-2026-10-28";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "8cf7f0fd3110a61c70c24a467eaaa265a16e2711";
      hash = "sha256-rdMSjz203R8pwY0y0VsrN47axCsIRWeNdEBgiqeXQjg=";
    };
    yarnHash = "sha256-hus/F92WpQ6JAfGRKtDNBhFqNuRWdemGBzPKxpzbtIg=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
