{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  addDriverRunpath,
  makeWrapper,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "nvencc";
  version = "9.38";

  src = fetchurl {
    url = "https://github.com/rigaya/NVEnc/releases/download/${finalAttrs.version}/nvencc_${finalAttrs.version}_amd64.deb";
    hash = "sha256-jA1UyXR62mkyB6LZ5nHvw2vv16ZgWFAvwqopnw6Zd6w=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib ];
  # Supplied by the consuming host's NVIDIA driver, never a build-time stub.
  autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];
  appendRunpaths = [ "${addDriverRunpath.driverLink}/lib" ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share"
    cp usr/bin/nvencc "$out/bin/nvencc"
    cp -r usr/share/. "$out/share/"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/nvencc" \
      --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib
  '';

  meta = {
    description = "NVENC command-line encoder with bundled CUDA processing kernels";
    homepage = "https://github.com/rigaya/NVEnc";
    # The upstream release links NVIDIA redistributables in addition to MIT code.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "nvencc";
    maintainers = [ lib.maintainers.huggy ];
  };
})
