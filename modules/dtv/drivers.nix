{
  a865r = {
    file = ../../kernel-modules/a865r.nix;
    modules = [ "a865r" ];
  };
  magicvision = {
    file = ../../pkgs/magicvision/package.nix;
    modules = [
      "dummy_hcd"
      "magicvision_ccid"
      "magicvision_usb"
    ];
  };
  pt3 = {
    file = ../../kernel-modules/pt3.nix;
    modules = [ "pt3_drv" ];
  };
  px4 = {
    file = ../../pkgs/px4-drv/package.nix;
    modules = [ "px4_drv" ];
  };
  siano = {
    file = ../../kernel-modules/siano-smsdvb.nix;
    modules = [
      "smsdvb"
      "smsmdtv"
    ];
  };
  tbs6812 = {
    file = ../../kernel-modules/tbs6812-drv.nix;
    modules = [
      "cxd2857"
      "tbs6812"
    ];
  };
}
