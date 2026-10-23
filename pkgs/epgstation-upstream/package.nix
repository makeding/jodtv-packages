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
    version = "3.0.0-beta3-unstable-2026-10-23";
    src = fetchFromGitHub {
      owner = "l3tnun";
      repo = "EPGStation";
      rev = "26e0105697a055595d1967e2b680cd8b9fb23870";
      hash = "sha256-tNcOSIq7cdcnaCvSAoqfkKkmbVdTup8FsDvNqH1W+cM=";
    };
    # On case-insensitive Darwin filesystems, the resolver chooses
    # extendedPagination.ts before ExtendedPagination.tsx. Give the component
    # an unambiguous basename without changing its behavior.
    clientPostPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
      mv src/shared/ExtendedPagination.tsx src/shared/ExtendedPaginationComponent.tsx
      substituteInPlace src/shared/AppPagination.tsx \
        --replace-fail "from './ExtendedPagination'" "from './ExtendedPaginationComponent'"
    '';
    npmDepsHash = "sha256-Gum0Nap5XvgvIMOMefLXvGfybYqnfqvomgk4zPffQxs=";
    clientNpmDepsHash = "sha256-Mt+RNGdFVXHmFzza+g7rbCC0B59sv5kAebsEKddReIo=";
  }
)
