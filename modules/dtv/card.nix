{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dtv.card;
in
{
  options.dtv.card = {
    enable = lib.mkEnableOption "PC/SC smart-card services and tools";
    rw5100Support = lib.mkEnableOption "the RW5100 PC/SC plugin and USB permissions";
    package = lib.mkPackageOption pkgs "pcsc-rw5100" { };
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional PC/SC reader plugins.";
    };
  };
  config = lib.mkIf cfg.enable {
    services.pcscd = {
      enable = true;
      plugins = cfg.plugins ++ lib.optional cfg.rw5100Support cfg.package;
    };
    environment.systemPackages = [
      pkgs.pcsc-tools
    ]
    ++ lib.optional cfg.rw5100Support cfg.package;
    services.udev.extraRules = lib.mkIf cfg.rw5100Support ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="04dd", ATTR{idProduct}=="9259", GROUP="pcscd", MODE="0660"
    '';
  };
}
