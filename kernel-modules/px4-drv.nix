{
  lib,
  stdenv,
  fetchFromGitHub,
  git,
  kernel,
  kernelModuleMakeFlags,
  buildPackages,
}:

stdenv.mkDerivation rec {
  pname = "px4-drv";
  version = "0.6.1";
  name = "${pname}-${version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "tsukumijima";
    repo = "px4_drv";
    rev = "d748866f0da1cb3656106a520de4e9d7f073aacd";
    hash = "sha256-YdB2kiVhYLi8TxZVL9eCksYtvri82Ybdlbe6uthkU/c=";
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
    description = "Unofficial Linux driver for PLEX PX4/PX5/PX-MLT and e-Better ISDB-T/S receivers";
    homepage = "https://github.com/tsukumijima/px4_drv";
    license = [
      lib.licenses.gpl2Only
      lib.licenses.unfree
    ];
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
