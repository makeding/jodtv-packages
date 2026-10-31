{
  lib,
  fetchFromGitHub,
  git,
  linuxPackages,
  kernel ? linuxPackages.kernel,
  kernelModuleMakeFlags ? kernel.commonMakeFlags ++ [
    "KBUILD_OUTPUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ],
  buildPackages,
}:

kernel.stdenv.mkDerivation rec {
  pname = "px4-drv";
  version = "0.7.0";
  name = "${pname}-${version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "px4_drv";
    rev = "317850e9af58dcf466b17650b2437b3b04b3ff87";
    hash = "sha256-vuT89Gexk/OeUMyPtDSdcHyN7/oJuLoAjKm6aI1TQJE=";
  };

  sourceRoot = "${src.name}/driver";

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ git ];

  makeFlags = kernelModuleMakeFlags ++ [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "px4_drv.ko"
  ];

  installPhase = ''
    runHook preInstall

    install -D -m 0444 px4_drv.ko \
      $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/usb/px4_drv/px4_drv.ko
    install -D -m 0444 ../etc/it930x-firmware.bin \
      $out/lib/firmware/it930x-firmware.bin
    mkdir -p $out/lib/udev/rules.d
    # Preserve upstream device coverage and power handling with group-only access.
    sed 's/MODE="0664"/MODE="0660"/g' ../etc/99-px4video.rules \
      > $out/lib/udev/rules.d/99-px4video.rules
    runHook postInstall
  '';

  # Custom installation bypasses Kbuild's signing rule. Sign the final
  # modules after fixup and keep the certificates required by the aggregator.
  postFixup = ''
    while IFS= read -r -d $'\0' module; do
      chmod u+w "$module"
      ${lib.getExe buildPackages.kmodigest} "$module"
      test -s "$module.cer"
    done < <(find "$out/lib/modules" -type f -name '*.ko' -print0)
  '';

  meta = {
    description = "Unofficial Linux driver for PLEX PX4/PX5/PX-MLT and e-Better ISDB-T/S/C receivers";
    homepage = "https://github.com/tsukumijima/px4_drv";
    license = [
      lib.licenses.gpl2Only
      lib.licenses.unfree
    ];
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
