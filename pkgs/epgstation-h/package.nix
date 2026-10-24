args@{
  callPackage,
  fetchFromGitHub,
  tsreplace,
  ...
}:
callPackage ./build.nix (
  builtins.removeAttrs args [
    "callPackage"
    "fetchFromGitHub"
    "tsreplace"
    "stdenv"
  ]
  // {
    version = "3.0.0-beta3-unstable-2026-10-24";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "EPGStation";
      rev = "cce7d1972eb6d208fc46f944cc0e313d9aae6526";
      hash = "sha256-EpTRRSd2EAhlJaD9UqiRzGkiZD5xriXf6mvfcT7wH2c=";
    };
    npmDepsHash = "sha256-zKlf7/n8DQdG+ChpCcArPQLNfN87L4OmuXpnCPUgenI=";
    clientNpmDepsHash = "sha256-Mt+RNGdFVXHmFzza+g7rbCC0B59sv5kAebsEKddReIo=";
    extraRuntimePackages = [ tsreplace ];
  }
)
