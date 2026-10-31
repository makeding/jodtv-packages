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
    version = "3.0.0-beta4-unstable-2026-10-31";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "EPGStation";
      rev = "dc91d6b9e6801e20f14bee89d4e409737c66653d";
      hash = "sha256-Yq9aovV5CqS+XfBJs3pQVhl3m3ZYqnmYQuq9RNImviw=";
    };
    npmDepsHash = "sha256-QN8K91xKwUbyKEtaYjMCSb8JshkYx74DW6SHHxVN/Sk=";
    clientNpmDepsHash = "sha256-XMLBpsQ7nIexHKFtt8tyE9/qLOx7dXBe1za3o1l7K38=";
    extraRuntimePackages = [ tsreplace ];
  }
)
