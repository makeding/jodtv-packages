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
    version = "0.14.1-unstable-2026-10-26";
    src = fetchFromGitHub {
      owner = "tsukumijima";
      repo = "KonomiTV";
      rev = "6b48bb48fad42333a4b22a308c970e61ebfd43be";
      hash = "sha256-Y+aIp4FzoCDyuqMX79Q68njLfU9AbGIH76UFaBMl2hc=";
    };
    yarnHash = "sha256-bvFWWJxYW/1Ej+Yvb5FoAm3/R9Mv0zHQUj73XHdoNhE=";
    description = "KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/tsukumijima/KonomiTV";
  }
)
