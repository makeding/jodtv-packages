{ callPackage, inputs }:
let
  amatsukaze = callPackage ./amatsukaze/package.nix { };
in
{
  a865r-firmware = callPackage ./a865r-firmware/package.nix { };
  inherit amatsukaze;
  amatsukaze-native = amatsukaze.sourceBuild;
  casproxyserver = callPackage ./casproxyserver/package.nix { };
  dantto4k = callPackage ./dantto4k/package.nix { };
  edcb-wine = callPackage ./edcb-wine/package.nix { };
  epgstation-h = callPackage ./epgstation-h/package.nix { };
  epgstation-upstream = callPackage ./epgstation-upstream/package.nix { };
  ffmpeg-libaribtlv = callPackage ./ffmpeg-libaribtlv/package.nix { };
  hiraku = callPackage ./hiraku/package.nix { };
  honomitv = callPackage ./honomitv/package.nix {
    inherit (inputs) pyproject-nix uv2nix pyproject-build-systems;
  };
  intel-media-sdk-h = callPackage ./intel-media-sdk-h/package.nix { };
  konomitv = callPackage ./konomitv/package.nix {
    inherit (inputs) pyproject-nix uv2nix pyproject-build-systems;
  };
  libaribb25 = callPackage ./libaribb25/package.nix { };
  libaribb61 = callPackage ./libaribb61/package.nix { };
  libaribtlv = callPackage ./libaribtlv/package.nix { };
  librw5100 = callPackage ./librw5100/package.nix { };
  mirakc = callPackage ./mirakc/package.nix { };
  mirakc-arib = callPackage ./mirakc-arib/package.nix { };
  mirakurun = callPackage ./mirakurun/package.nix { };
  mmt2ts = callPackage ./mmt2ts/package.nix { };
  nvencc = callPackage ./nvencc/package.nix { };
  pcsc-rw5100 = callPackage ./pcsc-rw5100/package.nix { };
  psisiarc = callPackage ./psisiarc/package.nix { };
  psisimux = callPackage ./psisimux/package.nix { };
  px4-drv = callPackage ./px4-drv/package.nix { };
  qsvencc = callPackage ./qsvencc/package.nix { };
  recisdb = callPackage ./recisdb/package.nix { };
  tsreadex = callPackage ./tsreadex/package.nix { };
  tsreplace = callPackage ./tsreplace/package.nix { };
}
