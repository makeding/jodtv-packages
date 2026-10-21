{ config, lib, ... }:
let
  cfg = config.hardware.jpdtv;
  drivers = {
    pt3 = {
      file = ../kernel-modules/pt3.nix;
      modules = [ "pt3_drv" ];
    };
    px4 = {
      file = ../kernel-modules/px4-drv.nix;
      modules = [ "px4_drv" ];
    };
    siano = {
      file = ../kernel-modules/siano-smsdvb.nix;
      modules = [
        "smsdvb"
        "smsmdtv"
      ];
    };
    tbs6812 = {
      file = ../kernel-modules/tbs6812-drv.nix;
      modules = [
        "cxd2857"
        "tbs6812"
      ];
    };
  };
  selected = map (name: drivers.${name}) cfg.tuners;
in
{
  options.hardware.jpdtv.tuners = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (builtins.attrNames drivers));
    default = [ ];
    example = [
      "pt3"
      "tbs6812"
    ];
    description = "Out-of-tree tuner drivers built for boot.kernelPackages. Firmware and device-specific parameters are configured by the host.";
  };
  config = {
    boot.extraModulePackages = map (
      driver: config.boot.kernelPackages.callPackage driver.file { }
    ) selected;
    boot.kernelModules = lib.concatMap (driver: driver.modules) selected;
  };
}
