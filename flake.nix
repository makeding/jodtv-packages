{
  description = "Japanese digital TV packages and NixOS modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "git+https://github.com/pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

    in
    {
      lib = import ./lib { inherit lib; };
      overlays.default = import ./overlay.nix { inherit inputs; };
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          all = import ./pkgs {
            inherit (pkgs) callPackage;
            inherit inputs;
          };
          darwin = [
            "hiraku"
            "libaribtlv"
            "psisiarc"
            "psisimux"
            "tsreadex"
            "tsreplace"
            "ffmpeg-libaribtlv"
          ];
          x86Only = [
            "honomitv"
            "konomitv"
            "intel-media-sdk-h"
            "qsvencc"
          ];
          names =
            if system == "aarch64-darwin" then
              darwin
            else if system == "aarch64-linux" then
              lib.subtractLists x86Only (builtins.attrNames all)
            else
              builtins.attrNames all;
        in
        lib.getAttrs names all
      );

      nixosModules = {
        packages = {
          nixpkgs.overlays = [ self.overlays.default ];
        };
        default = {
          imports = with self.nixosModules; [
            packages
            dtv
            honomitv
          ];
        };
        hirakud = ./modules/hirakud.nix;
        honomitv = ./modules/honomitv;
        epgstation = ./modules/epgstation.nix;
        dtv = ./modules/dtv;
      };
      checks = forAllSystems (
        system:
        import ./checks {
          inherit self nixpkgs;
          pkgs = pkgsFor system;
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
