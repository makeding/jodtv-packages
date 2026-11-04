{
  lib,
  fetchFromGitHub,
  linuxPackages,
  kernel ? linuxPackages.kernel,
  kernelModuleMakeFlags ? kernel.commonMakeFlags ++ [
    "KBUILD_OUTPUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ],
  buildPackages,
  firmware ? buildPackages.callPackage ../magicvision-firmware/package.nix { },
}:

kernel.stdenv.mkDerivation {
  pname = "magicvision";
  version = "unstable-2026-11-04-${kernel.version}";
  src = fetchFromGitHub {
    owner = "makeding";
    repo = "mAgicVISION";
    rev = "17e4b8d13454b0190e4d15de77d74f46677a159a";
    hash = "sha256-EvcBXae61WcBWoI+DV/sX0OZJLHlRZIqfetO+X8AN0M=";
  };
  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [ "pic" ];
  postPatch = ''
    install -Dm444 ${firmware}/lib/firmware/magicvision/firmware.bin firmware/firmware.bin
  '';
  buildPhase = ''
    runHook preBuild
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M="$PWD" ${lib.escapeShellArgs kernelModuleMakeFlags} modules
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    for name in magicvision_ccid magicvision_usb; do
      install -Dm444 "$name.ko" \
        "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/usb/magicvision/$name.ko"
    done
    install -Dm444 linux/60-mb86H.rules "$out/lib/udev/rules.d/60-magicvision.rules"
    runHook postInstall
  '';
  postFixup = ''
    for name in magicvision_ccid magicvision_usb; do
      module="$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/usb/magicvision/$name.ko"
      chmod u+w "$module"
      ${lib.getExe buildPackages.kmodigest} "$module"
      test -s "$module.cer"
    done
  '';
  passthru = { inherit firmware; };
  meta = {
    description = "mb86H Series USB DVB and CCID drivers with release firmware";
    homepage = "https://github.com/makeding/mAgicVISION";
    license = [
      lib.licenses.gpl2Only
      lib.licenses.unfree
    ];
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
