{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  buildPackages,
}:

stdenv.mkDerivation rec {
  pname = "a865r";
  version = "unstable-2026-10-23";
  name = "${pname}-${version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "a865r";
    rev = "be75837bfe097689c35b163cf1f033567f88fde4";
    hash = "sha256-qbfn5Uu6+cLMJ91qQpL+EaEx4YTlYbBRICV+Lz4s0Y4=";
  };

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  buildPhase = ''
    runHook preBuild

    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M="$PWD" ${lib.concatStringsSep " " kernelModuleMakeFlags} modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -D -m 0444 a865r.ko \
      $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/usb/a865r/a865r.ko

    runHook postInstall
  '';

  # Custom installation bypasses Kbuild's signing rule. Sign the final
  # module and preserve the certificate used by the module aggregator.
  postFixup = ''
    chmod u+w "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/usb/a865r/a865r.ko"
    ${lib.getExe buildPackages.kmodigest} \
      "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/usb/a865r/a865r.ko"
    test -s "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/media/usb/a865r/a865r.ko.cer"
  '';

  meta = {
    description = "Out-of-tree Linux DVB driver for the AVerMedia A865 ISDB-T USB receiver";
    homepage = "https://github.com/makeding/a865r";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ lib.maintainers.huggy ];
  };
}
