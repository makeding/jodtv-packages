{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  python3,
  fontconfig,
  noto-fonts-cjk-sans,
  writeText,
  addDriverRunpath,
  zlib,
  krb5,
  glibc,
  runtimeShell,
  callPackage,
  fetchFromGitHub,
  ffmpeg-libaribtlv,
  ffmpeg,
  bs4k ? false,
  tsreplace,
  gpac,
}:
let
  version = "1.1.1.3";
  sourceBuild = callPackage ./native.nix {
    inherit version;
    ffmpeg = if bs4k then ffmpeg else ffmpeg-libaribtlv;
    src = fetchFromGitHub {
      owner = "rigaya";
      repo = "Amatsukaze";
      rev = version;
      hash = "sha256-5kqbanjIBAJMlO1I/bvo7wVZkinyBewneZMtFBZUH/s=";
      fetchSubmodules = true;
    };
  };
  mp4box = gpac.override {
    ffmpeg-headless = ffmpeg;
    withFfmpeg = true;
  };
  fonts = writeText "amatsukaze-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">${fontconfig.out}/etc/fonts/fonts.conf</include>
      <dir>${noto-fonts-cjk-sans}/share/fonts</dir>
    </fontconfig>
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "amatsukaze";
  inherit version;

  src = fetchurl {
    url = "https://github.com/rigaya/Amatsukaze/releases/download/${finalAttrs.version}/Amatsukaze_linux_${finalAttrs.version}_x64.tar.xz";
    hash = "sha256-WBG5QCndaTb1IseRnVbVZiYca7N8p2h2gzTo6ifyszU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Preserve bundled runtime binaries and their embedded .NET assemblies.
  dontStrip = true;
  dontPatchShebangs = true;
  # .NET single-file hosts have embedded payload offsets and non-contiguous
  # NOTE sections. Keep their bytes intact and invoke them via the Nix loader.
  dontAutoPatchelf = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/amatsukaze" "$out/bin"
    cp -a exe_files avs avscache bat profile JL logo drcs scripts \
      basepkg-manifest.json "$out/share/amatsukaze/"
    mkdir dotnet-unpatched
    for program in AmatsukazeServerCLI AmatsukazeAddTask ScriptCommand AmatsukazeDockerConfigFix; do
      mv "$out/share/amatsukaze/exe_files/$program" dotnet-unpatched/
    done
    # The archive carries every non-glibc ELF dependency, including ICU and
    # AviSynth. Keep those versions together with the self-contained runtime.
    addAutoPatchelfSearchPath "$out/share/amatsukaze/exe_files"
    makeWrapper ${python3}/bin/python "$out/bin/amatsukaze" \
      --add-flags "${./run.py} --bundle $out/share/amatsukaze" \
      --prefix PATH : ${lib.makeBinPath [ python3 ]} \
      --set FONTCONFIG_FILE ${fonts} \
      --set AMT_ENABLE_SELF_UPDATE 0 \
      --set DOTNET_SYSTEM_GLOBALIZATION_APPLOCALICU 76.1 \
      --prefix LD_LIBRARY_PATH : "$out/share/amatsukaze/exe_files/lib:${
        lib.makeLibraryPath [
          zlib
          krb5
        ]
      }:${addDriverRunpath.driverLink}/lib" \
      --set OPENSSL_MODULES "$out/share/amatsukaze/exe_files/lib/ossl-modules"
    makeWrapper "$out/bin/amatsukaze" "$out/bin/amatsukaze-cli" --add-flags cli
    makeWrapper "$out/bin/amatsukaze" "$out/bin/amatsukaze-add-task" --add-flags add-task
    runHook postInstall
  '';

  postFixup = ''
    autoPatchelf "$out"
    for program in AmatsukazeServerCLI AmatsukazeAddTask ScriptCommand AmatsukazeDockerConfigFix; do
      install -m755 "dotnet-unpatched/$program" "$out/share/amatsukaze/exe_files/.$program-unwrapped"
      substitute ${./dotnet-host.sh} "$out/share/amatsukaze/exe_files/$program" \
        --subst-var-by shell ${runtimeShell} \
        --subst-var-by loader ${glibc}/lib/ld-linux-x86-64.so.2 \
        --subst-var-by glibc ${glibc}
      chmod +x "$out/share/amatsukaze/exe_files/$program"
    done
  ''
  + lib.optionalString bs4k ''
    # Replace every bundled libav consumer, including the --loadv2 engine.
    rm "$out/share/amatsukaze/exe_files/"{libAmatsukaze.so,libAmatsukaze2.so,AmatsukazeCLI,AmatsukazeGenLogo,tsreplace,MP4Box}
    for library in libAmatsukaze.so libAmatsukaze2.so; do
      ln -s ${sourceBuild}/lib/$library "$out/share/amatsukaze/exe_files/$library"
    done
    for program in AmatsukazeCLI AmatsukazeGenLogo; do
      cp ${sourceBuild}/bin/$program "$out/share/amatsukaze/exe_files/$program"
    done
    ln -s ${tsreplace}/bin/tsreplace "$out/share/amatsukaze/exe_files/tsreplace"
    ln -s ${mp4box}/bin/MP4Box "$out/share/amatsukaze/exe_files/MP4Box"
    rm "$out/share/amatsukaze/exe_files/lib/"{libstdc++.so.6,libgcc_s.so.1}
    ln -s ${sourceBuild.compilerRuntime}/lib/libstdc++.so.6 "$out/share/amatsukaze/exe_files/lib/libstdc++.so.6"
    ln -s ${sourceBuild.compilerRuntime}/lib/libgcc_s.so.1 "$out/share/amatsukaze/exe_files/lib/libgcc_s.so.1"
  '';

  passthru = {
    inherit sourceBuild bs4k;
  }
  // lib.optionalAttrs bs4k {
    inherit mp4box tsreplace;
  };

  meta = {
    description = "Automated MPEG-TS transcoder with CM analysis, subtitles and WebUI";
    homepage = "https://github.com/rigaya/Amatsukaze";
    # Mixed upstream binary bundle; retain its individual component licenses.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "amatsukaze";
    maintainers = [ lib.maintainers.huggy ];
  };
})
