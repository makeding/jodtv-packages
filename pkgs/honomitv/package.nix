args@{
  callPackage,
  fetchFromGitHub,
  python314,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  pythonInterpreter ? python314,
  ...
}:
callPackage ./build.nix (
  builtins.removeAttrs args [ "fetchFromGitHub" ]
  // {
    inherit
      pyproject-nix
      uv2nix
      pyproject-build-systems
      pythonInterpreter
      ;
    pname = "honomitv";
    generateLogos = true;
    version = "0.14.1-unstable-2026-10-27";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "HonomiTV";
      rev = "fc7dd66d6041991df02f110fec1dd7211e3c2691";
      hash = "sha256-3AxaVrk9tgXacgQn+EB35PJWVD58P11f+2bUPrb0yBE=";
    };
    yarnHash = "sha256-jqg/e6NB5HLi7idxxfJL5T5oRrm720zYTzQ8EXb/QpQ=";
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
  }
)
