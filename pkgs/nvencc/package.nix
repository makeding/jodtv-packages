{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  addDriverRunpath,
  makeWrapper,
  callPackage,
  fetchFromGitHub,
  ffmpeg,
  fromSource ? false,
}:
let
  version = "9.40";
  sourceBuild = callPackage ./source.nix {
    inherit version ffmpeg;
    src = fetchFromGitHub {
      owner = "rigaya";
      repo = "NVEnc";
      rev = version;
      hash = "sha256-7D7B+C4mMBBnlc9heIPN9hDbr9/XHEsN1CHD2SATvIY=";
      fetchSubmodules = true;
    };
  };
in
if fromSource then
  sourceBuild
else
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "nvencc";
    inherit version;

    src = fetchurl {
      url = "https://github.com/rigaya/NVEnc/releases/download/${finalAttrs.version}/nvencc_${finalAttrs.version}_amd64.deb";
      hash = "sha256-3y5vjlINn6PBJi0knk/nzFghRNJgI5+Vya9ZwZWoKyU=";
    };

    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
      makeWrapper
    ];
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
      if test -d usr/share; then cp -r usr/share/. "$out/share/"; fi
      runHook postInstall
    '';

    postFixup = ''
      wrapProgram "$out/bin/nvencc" \
        --prefix LD_LIBRARY_PATH : ${addDriverRunpath.driverLink}/lib
    '';

    passthru = {
      inherit sourceBuild;
      fromSource = false;
    };

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
