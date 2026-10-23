args@{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  ...
}:
callPackage ../epgstation-h/build.nix (
  builtins.removeAttrs args [
    "callPackage"
    "fetchFromGitHub"
    "tsreplace"
    "stdenv"
  ]
  // {
    readmeFile = "README.md";
    documentationDir = "docs";
    version = "3.0.0-beta2-unstable-2026-10-14";
    src = fetchFromGitHub {
      owner = "l3tnun";
      repo = "EPGStation";
      rev = "1793ab74088be8791d191c9621ab881e50741119";
      hash = "sha256-AAh1BtEEt/KQHFH5gDyfmFs5bdJjKj5GUxrXyF2/2O0=";
    };
    # On case-insensitive Darwin filesystems, the resolver chooses
    # extendedPagination.ts before ExtendedPagination.tsx. Give the component
    # an unambiguous basename without changing its behavior.
    clientPostPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
      mv src/shared/ExtendedPagination.tsx src/shared/ExtendedPaginationComponent.tsx
      substituteInPlace src/shared/AppPagination.tsx \
        --replace-fail "from './ExtendedPagination'" "from './ExtendedPaginationComponent'"
    '';
    npmDepsHash = "sha256-lM96fjZTHe13/qhmxZSZyGfXwwrRIUz/7F1PwuUNaDY=";
    clientNpmDepsHash = "sha256-NPVpmcunFihkDn7qP+wdvKJuGrF4c3C9ldsTprh32wM=";
  }
)
