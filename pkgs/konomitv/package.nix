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
    version = "0.14.1-unstable-2026-10-22";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "11da11ee5b65a0ac9fafc92b200209316ebe6d48";
      hash = "sha256-eTqyEVO7maHS8AAf3s/f8/Mbj3B+DjyvdzY6KSIsn/o=";
    };
    yarnHash = "sha256-wj9/e0lond6Jq7GGJ7R+DrSaQm9QYwP2i45LdHtz0mU=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
