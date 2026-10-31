{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  runCommand,
  python3,
  coreutils,
  mirakc-arib,
}:

rustPlatform.buildRustPackage (finalAttrs: rec {
  pname = "mirakc";
  version = "3.4.92";

  src = fetchFromGitHub {
    owner = "mirakc";
    repo = "mirakc";
    tag = version;
    hash = "sha256-PbWRl0a54fZc93ZbNvKsVpw4TFgcMs3tF+IO4Q3M8P0=";
  };
  cargoHash = "sha256-YxKTZAjMyv8V+MP7mCp1e+t3UIcJwLEXritToBN62qE=";

  # The workspace also contains the optional FUSE timeshift filesystem.
  cargoBuildFlags = [
    "--package"
    "mirakc"
  ];
  cargoTestFlags = [
    "--package"
    "mirakc"
  ];
  nativeBuildInputs = [ makeWrapper ];

  # fs::copy preserves permissions: a store input leaves a read-only ZIP in
  # OUT_DIR that subsequent build-script runs cannot overwrite.
  preBuild = ''
    install -m644 ${
      fetchurl {
        url = "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v5.32.6.zip";
        hash = "sha256-s8B+CRVZtZqDP2ZUfrH8GPKJb5bj8flT4vHvsyiqM5Q=";
      }
    } "$NIX_BUILD_TOP/swagger-ui.zip"
    export SWAGGER_UI_DOWNLOAD_URL="file://$NIX_BUILD_TOP/swagger-ui.zip"
  '';
  VERGEN_GIT_SHA = src.rev;

  postPatch = ''
    substituteInPlace mirakc-core/src/config.rs \
      --replace-fail /etc/mirakc/strings.yml $out/share/mirakc/strings.yml
  '';

  postInstall = ''
    install -Dm644 resources/strings.yml $out/share/mirakc/strings.yml
    wrapProgram $out/bin/mirakc \
      --prefix PATH : ${
        lib.makeBinPath [
          mirakc-arib
          coreutils
        ]
      }
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/mirakc --version | grep -F '${version}'
    $out/bin/mirakc --help >/dev/null
    test -s $out/share/mirakc/strings.yml
    runHook postInstallCheck
  '';

  passthru.tests.smoke =
    runCommand "mirakc-smoke"
      {
        nativeBuildInputs = [ python3 ];
      }
      ''
        python ${./smoke-test.py} ${finalAttrs.finalPackage}/bin/mirakc ${version}
        touch $out
      '';

  meta = {
    description = "Mirakurun-compatible PVR backend written in Rust";
    homepage = "https://github.com/mirakc/mirakc";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = lib.platforms.linux;
    mainProgram = "mirakc";
    maintainers = [ lib.maintainers.huggy ];
  };
})
