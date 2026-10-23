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
    version = "3.0.0-beta3-unstable-2026-10-23";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "EPGStation";
      rev = "5396bffeae34a4b405449096c88fca63296cd5f9";
      hash = "sha256-q8O7f3NsaX43UUynB3Fbg0hMIaP1+jdUAWKY55cyjzk=";
    };
    npmDepsHash = "sha256-zKlf7/n8DQdG+ChpCcArPQLNfN87L4OmuXpnCPUgenI=";
    clientNpmDepsHash = "sha256-Mt+RNGdFVXHmFzza+g7rbCC0B59sv5kAebsEKddReIo=";
    extraRuntimePackages = [ tsreplace ];
  }
)
