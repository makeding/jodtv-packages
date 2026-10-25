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
    version = "3.0.0-beta4-unstable-2026-10-25";
    src = fetchFromGitHub {
      owner = "l3tnun";
      repo = "EPGStation";
      rev = "8b0cc6f569792a7115106020523b72b086142c08";
      hash = "sha256-5f+VJK0NlixtPhyFI114KY89QBO4/1u2vhzo9S2I2m8=";
    };
    # On case-insensitive Darwin filesystems, the resolver chooses
    # extendedPagination.ts before ExtendedPagination.tsx. Give the component
    # an unambiguous basename without changing its behavior.
    clientPostPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
      mv src/shared/ExtendedPagination.tsx src/shared/ExtendedPaginationComponent.tsx
      substituteInPlace src/shared/AppPagination.tsx \
        --replace-fail "from './ExtendedPagination'" "from './ExtendedPaginationComponent'"
    '';
    npmDepsHash = "sha256-toOd9UX8ZuPMWsBiwR5DJBoZZ7sYct7EO+kUbzMlpIE=";
    clientNpmDepsHash = "sha256-XMLBpsQ7nIexHKFtt8tyE9/qLOx7dXBe1za3o1l7K38=";
  }
)
