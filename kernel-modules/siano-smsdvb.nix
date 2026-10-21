{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  buildPackages,
}:

stdenv.mkDerivation rec {
  pname = "siano-smsdvb";
  version = "unstable-2026-07-12";
  name = "${pname}-${version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "RGBA-CRT";
    repo = "siano_smsdvb_dkms";
    rev = "db0018c030a48ff70529956718c6e30d645670e5";
    hash = "sha256-0TrBv0qzj5nfet7bgLwocFWC064OrgrRnM0cdsT0yOc=";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  postPatch = ''
    sed -i 's/MODULE_DESCRIPTION("SMS DVB subsystem adaptation module")/MODULE_DESCRIPTION("SMS DVB subsystem adaptation module (patched)")/' smsdvb-main.c
    sed -i 's/MODULE_DESCRIPTION("Siano MDTV Core module")/MODULE_DESCRIPTION("Siano MDTV Core module (patched)")/' smscoreapi.c
  '';

  makeFlags = kernelModuleMakeFlags ++ [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    install -D -m 0444 smsmdtv.ko \
      $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/common/siano/smsmdtv.ko
    install -D -m 0444 smsdvb.ko \
      $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/common/siano/smsdvb.ko

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
    description = "Out-of-tree Linux DVB driver for Siano Mobile Silicon receivers";
    homepage = "https://github.com/RGBA-CRT/siano_smsdvb_dkms";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
