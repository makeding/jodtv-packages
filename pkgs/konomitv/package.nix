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
    version = "0.14.1-unstable-2026-10-25";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "1e5a0a1ba65a038e983c451620ea8224b342b7c0";
      hash = "sha256-+mYVhE1qln988HvRct53CSUM5k7m+3+vCWQlhUnPous=";
    };
    yarnHash = "sha256-wj9/e0lond6Jq7GGJ7R+DrSaQm9QYwP2i45LdHtz0mU=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
