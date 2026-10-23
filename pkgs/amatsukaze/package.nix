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
}:
let
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
  version = "1.1.1.3";

  src = fetchurl {
    url = "https://github.com/rigaya/Amatsukaze/releases/download/${finalAttrs.version}/Amatsukaze_linux_${finalAttrs.version}_x64.tar.xz";
    hash = "sha256-WBG5QCndaTb1IseRnVbVZiYca7N8p2h2gzTo6ifyszU=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Preserve bundled runtime binaries and their embedded .NET assemblies.
  dontStrip = true;
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/amatsukaze" "$out/bin"
    cp -a exe_files avs avscache bat profile JL logo drcs scripts \
      basepkg-manifest.json "$out/share/amatsukaze/"
    # The archive carries every non-glibc ELF dependency, including ICU and
    # AviSynth. Keep those versions together with the self-contained runtime.
    addAutoPatchelfSearchPath "$out/share/amatsukaze/exe_files"
    makeWrapper ${python3}/bin/python "$out/bin/amatsukaze" \
      --add-flags "${./run.py} --bundle $out/share/amatsukaze" \
      --prefix PATH : ${lib.makeBinPath [ python3 ]} \
      --set FONTCONFIG_FILE ${fonts} \
      --set AMT_ENABLE_SELF_UPDATE 0 \
      --set DOTNET_SYSTEM_GLOBALIZATION_APPLOCALICU 76.1 \
      --prefix LD_LIBRARY_PATH : "$out/share/amatsukaze/exe_files/lib:${lib.makeLibraryPath [ zlib krb5 ]}:${addDriverRunpath.driverLink}/lib" \
      --set OPENSSL_MODULES "$out/share/amatsukaze/exe_files/lib/ossl-modules"
    makeWrapper "$out/bin/amatsukaze" "$out/bin/amatsukaze-cli" --add-flags cli
    makeWrapper "$out/bin/amatsukaze" "$out/bin/amatsukaze-add-task" --add-flags add-task
    runHook postInstall
  '';

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
