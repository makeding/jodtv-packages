{ inputs }:
final: _prev:
let
  packages = import ./pkgs {
    inherit (final) callPackage;
    inherit inputs;
  };
in
packages
// {
  epgstation = packages.epgstation-h;
}
