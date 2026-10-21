{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  buildPackages,
}:

stdenv.mkDerivation rec {
  pname = "tbs6812-drv";
  version = "0.2.0-unstable-2026-09-03";
  name = "${pname}-${version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "otya128";
    repo = "tbs6812_drv";
    rev = "53bcdf77fc70ac3f9fb3e1890b21df56c7a1f892";
    hash = "sha256-Fhw+bbXiGvjG023nlJCZDwQ2zDUY1Xx58U+ajVvJ5Tg=";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -D -m 0444 tbs6812.ko \
      $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/pci/tbs6812/tbs6812.ko
    install -D -m 0444 cxd2857.ko \
      $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/dvb-frontends/cxd2857.ko

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
    description = "Linux drivers for TBS6812 and PT4K ISDB-T/S/S3 tuner cards";
    homepage = "https://github.com/otya128/tbs6812_drv";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
