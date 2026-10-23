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
    version = "3.0.0-beta2-unstable-2026-10-22";
    src = fetchFromGitHub {
      owner = "makeding";
      repo = "EPGStation";
      rev = "5015d9c13975ffd5a5fce2b6973f46b57c986167";
      hash = "sha256-kOl9LYULfUmGK7vuxdBt7d7JeL6ALnJK2kIIYYMNcuY=";
    };
    npmDepsHash = "sha256-dBqcxTfpgqvy0jE6cmsu+1h+gCJRJYLK9nypIOTUsZA=";
    clientNpmDepsHash = "sha256-NPVpmcunFihkDn7qP+wdvKJuGrF4c3C9ldsTprh32wM=";
    extraRuntimePackages = [ tsreplace ];
  }
)
