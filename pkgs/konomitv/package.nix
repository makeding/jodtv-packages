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
    version = "0.14.1-unstable-2026-10-23";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "9a11093953c057073e021ef07a97a958662fddad";
      hash = "sha256-S6wajy1zhb4ZaRgut+Py+aS+qCVYQFCxf3Sva5mFYgs=";
    };
    yarnHash = "sha256-wj9/e0lond6Jq7GGJ7R+DrSaQm9QYwP2i45LdHtz0mU=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
