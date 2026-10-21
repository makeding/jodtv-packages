{
  lib,
  stdenv,
  fetchFromGitHub,
  git,
  kernel,
  kernelModuleMakeFlags,
  buildPackages,
  kmod,
}:

stdenv.mkDerivation rec {
  pname = "pt3";
  version = "de82e6a747b68ed7cc51de30193f29f82c0e617f";
  name = "${pname}-${version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "m-tsudo";
    repo = "pt3";
    rev = version;
    hash = "sha256-GG2NRfCqw/Gt5+Vh5Isjp8cvkfgBPnsor8o5+NsKhWs=";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    git
    kmod
  ];

  postPatch = ''
    sed -i '/depmod/d' Makefile
  '';

  makeFlags = kernelModuleMakeFlags ++ [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KBUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KVER=${kernel.modDirVersion}"
  ];

  installPhase = ''
    runHook preInstall

    make install \
      KVER=${kernel.modDirVersion} \
      INSTALL_DIR=$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/video

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
    description = "Linux driver for Earthsoft PT3 ISDB-T/S tuner cards";
    homepage = "https://github.com/m-tsudo/pt3";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
