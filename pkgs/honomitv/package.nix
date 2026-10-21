{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  python314,
  makeWrapper,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  coreutils,
  ffmpeg-headless,
  qsvencc ? null,
  tsreadex,
  psisiarc,
  psisimux,
  yarn,
  nodejs,
  fetchYarnDeps,
  prefetch-yarn-deps,
  yarnConfigHook,
  yarnBuildHook,
  pythonInterpreter ? python314,
}:
let
  pname = "honomitv";
  version = "0.14.1-unstable-2026-10-21";
  python = pythonInterpreter;

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "HonomiTV";
    # Public makeding/HonomiTV fork, pinned to a clean committed revision.
    rev = "362adee838d9e013ad869e4089e0f72eeac43910";
    hash = "sha256-+iALgTKHJ8FtLvB9Iz2E0yoSyg8do6W6Ap5KWYp+Gx8=";
  };

  qsvenccForHost = if stdenv.hostPlatform.isLinux then qsvencc else null;

  pythonManifest = src + "/server/pyproject.toml";
  pythonLock = src + "/server/uv.lock";
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = src + "/server";
  };
  pyprojectOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
    pythonVersion = python.pythonVersion;
  };
  setuptoolsBuildSystemPackages = [
    "elevate"
    "grapheme"
    "pyjsparser"
  ];
  buildSystemOverrides =
    final: prev:
    lib.genAttrs setuptoolsBuildSystemPackages (
      name:
      prev.${name}.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem {
            setuptools = [ ];
          };
      })
    );
  pythonSet =
    (callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.wheel
          pyprojectOverlay
          buildSystemOverrides
        ]
      );
  pythonEnv = pythonSet.mkVirtualEnv "honomitv-env" workspace.deps.default;

  # Build the frontend using yarn (like the existing client/package.nix)
  frontend =
    let
      clientSrc = "${src}/client";
      logosSrc = "${src}/server/static/logos";
    in
    stdenv.mkDerivation {
      pname = "honomitv-client";
      inherit version;

      src = clientSrc;
      inherit logosSrc;

      nativeBuildInputs = [
        nodejs
        yarn
        prefetch-yarn-deps
        yarnConfigHook
        yarnBuildHook
      ];

      offlineCache = fetchYarnDeps {
        yarnLock = "${src}/client/yarn.lock";
        hash = "sha256-ntJ61HaneW0M5UhfivkjLSET44cd15pErsYsutiOReM=";
      };

      buildPhase = ''
        export HOME=$(mktemp -d)
        rm -fr dist
        cp -r ${logosSrc} logos
        node logoGenerator.js
        yarn --offline build
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/honomitv
        cp -r dist/* $out/share/honomitv/

        # Patch built JS files to replace crypto.randomUUID with fallback for HTTP compatibility
        for jsfile in $out/share/honomitv/assets/*.js; do
          if [ -f "$jsfile" ]; then
            substituteInPlace "$jsfile" \
              --replace-warn 'crypto.randomUUID()' \
                             '(crypto.randomUUID?crypto.randomUUID():"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,function(c){var r=Math.random()*16|0;return(c==="x"?r:(r&0x3|0x8)).toString(16)}))'
          fi
        done

        runHook postInstall
      '';
    };
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    ffmpeg-headless
    stdenv.cc.cc.lib # Provides libstdc++ for curl_cffi
  ];

  # Patch to disable Akebi HTTPS Server and make uvicorn listen address configurable
  postPatch = ''
    cd server

    # Remove local .venv if it exists (from local development)
    rm -rf .venv

    # Make logs, data, and client directories configurable via environment variables
    # First add os import if not already present
    substituteInPlace app/constants.py \
      --replace-fail "import base64" "import base64"$'\n'"import os" \
      --replace-fail "CLIENT_DIR = BASE_DIR.parent / 'client/dist'" \
                     "CLIENT_DIR = Path(os.environ.get('FRONTEND_BUILD_DIR', BASE_DIR.parent / 'client/dist'))" \
      --replace-fail "LOGS_DIR = BASE_DIR / 'logs'" \
                     "LOGS_DIR = Path(os.environ.get('HONOMITV_LOGS_DIR', BASE_DIR / 'logs'))" \
      --replace-fail "DATA_DIR = BASE_DIR / 'data'" \
                     "DATA_DIR = Path(os.environ.get('HONOMITV_DATA_DIR', BASE_DIR / 'data'))"

    # Make config.yaml path configurable via environment variable
    substituteInPlace app/config.py \
      --replace-fail "import asyncio" "import asyncio"$'\n'"import os" \
      --replace-fail "_CONFIG_YAML_PATH = BASE_DIR.parent / 'config.yaml'" \
                     "_CONFIG_YAML_PATH = Path(os.environ.get('HONOMITV_CONFIG_PATH', BASE_DIR.parent / 'config.yaml'))"

    # The NixOS module exposes Uvicorn directly.  Keep the upstream startup
    # lifecycle intact, but replace Akebi with a local no-op and skip its
    # third-party validation; it never performs network I/O.
    substituteInPlace app/constants.py \
      --replace-fail "'Akebi': str(LIBRARY_DIR / 'Akebi/akebi-https-server') + LIBRARY_EXTENSION," \
                     "'Akebi': '${lib.getExe' coreutils "true"}',"

    # Skip the third-party encoders that this package does not provide.
    substituteInPlace KonomiTV.py \
      --replace-fail "    for library_name, library_path in LIBRARY_PATH.items():" \
                     "    for library_name, library_path in LIBRARY_PATH.items():"$'\n'"        # Skip checks for encoders not provided by Nix build"$'\n'"        if library_name in ['Akebi', 'NVEncC', 'VCEEncC', 'rkmppenc']:"$'\n'"            continue"

    # Change uvicorn to listen on configurable host and use configured port directly
    substituteInPlace KonomiTV.py \
      --replace-fail "location='./app/migrations/'" "location=str(BASE_DIR / 'app/migrations')" \
      --replace-fail "host = '127.0.0.77'," "host = os.environ.get('HONOMITV_HOST', '0.0.0.0')," \
      --replace-fail "port = CONFIG.server.port + 10," "port = CONFIG.server.port,"

    # Fix model discovery to use absolute path based on BASE_DIR instead of relative path
    substituteInPlace app/constants.py \
      --replace-fail "__model_list = [name for _, name, _ in pkgutil.iter_modules(path=['app/models'])]" \
                     "__model_list = [name for _, name, _ in pkgutil.iter_modules(path=[str(BASE_DIR / 'app/models')])]"

    # Patch constants.py to use Nix-provided tools instead of thirdparty versions
    # Other tools (NVEncC, VCEEncC, rkmppenc) will still use thirdparty directory
    substituteInPlace app/constants.py \
      --replace-fail "'FFmpeg': str(LIBRARY_DIR / 'FFmpeg/ffmpeg') + LIBRARY_EXTENSION," \
                     "'FFmpeg': '${ffmpeg-headless}/bin/ffmpeg'," \
      --replace-fail "'FFprobe': str(LIBRARY_DIR / 'FFmpeg/ffprobe') + LIBRARY_EXTENSION," \
                     "'FFprobe': '${ffmpeg-headless}/bin/ffprobe'," \
      --replace-fail "'tsreadex': str(LIBRARY_DIR / 'tsreadex/tsreadex') + LIBRARY_EXTENSION," \
                     "'tsreadex': '${tsreadex}/bin/tsreadex'," \
      --replace-fail "'psisiarc': str(LIBRARY_DIR / 'psisiarc/psisiarc') + LIBRARY_EXTENSION," \
                     "'psisiarc': '${psisiarc}/bin/psisiarc'," \
      --replace-fail "'psisimux': str(LIBRARY_DIR / 'psisimux/psisimux') + LIBRARY_EXTENSION," \
                     "'psisimux': '${psisimux}/bin/psisimux',"

    ${lib.optionalString (qsvenccForHost != null) ''
      # Patch QSVEncC to use Nix-provided version (Linux only)
      substituteInPlace app/constants.py \
        --replace-fail "'QSVEncC': str(LIBRARY_DIR / 'QSVEncC/QSVEncC') + LIBRARY_EXTENSION," \
                       "'QSVEncC': '${qsvenccForHost}/bin/qsvencc',"
    ''}

    cd ..
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    cd server
    mkdir -p $out/lib/honomitv

    # Link the pure Nix-built virtualenv and copy application files.
    ln -s ${pythonEnv} $out/lib/honomitv/.venv
    cp -r app $out/lib/honomitv/
    cp -r data $out/lib/honomitv/
    cp -r static $out/lib/honomitv/
    cp -r thirdparty $out/lib/honomitv/
    cp KonomiTV.py $out/lib/honomitv/
    cp KonomiTV-Service.py $out/lib/honomitv/
    cp ${pythonManifest} $out/lib/honomitv/pyproject.toml
    cp ${pythonLock} $out/lib/honomitv/uv.lock

    # Create bin directory and wrapper
    mkdir -p $out/bin

    makeWrapper ${pythonEnv}/bin/python $out/bin/honomitv \
      --add-flags "$out/lib/honomitv/KonomiTV.py" \
      --set FRONTEND_BUILD_DIR ${frontend}/share/honomitv \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]} \
      --run 'export HONOMITV_LOGS_DIR=''${HONOMITV_LOGS_DIR:-./logs}' \
      --run 'export HONOMITV_DATA_DIR=''${HONOMITV_DATA_DIR:-./data}' \
      --run 'export HONOMITV_CONFIG_PATH=''${HONOMITV_CONFIG_PATH:-./config.yaml}' \
      --run 'case "$HONOMITV_LOGS_DIR" in /*) ;; *) HONOMITV_LOGS_DIR="$PWD/$HONOMITV_LOGS_DIR" ;; esac' \
      --run 'case "$HONOMITV_DATA_DIR" in /*) ;; *) HONOMITV_DATA_DIR="$PWD/$HONOMITV_DATA_DIR" ;; esac' \
      --run 'case "$HONOMITV_CONFIG_PATH" in /*) ;; *) HONOMITV_CONFIG_PATH="$PWD/$HONOMITV_CONFIG_PATH" ;; esac' \
      --run 'mkdir -p "$HONOMITV_LOGS_DIR" "$HONOMITV_DATA_DIR"'

    runHook postInstall
  '';

  meta = with lib; {
    description = "HonomiTV fork of KonomiTV: Kept Organized, Notably Optimized, Modern Interface TV media server";
    homepage = "https://github.com/makeding/HonomiTV";
    # License.txt in the pinned source tree is the MIT license, with the
    # upstream copyright notice intact.
    license = licenses.mit;
    maintainers = [ lib.maintainers.huggy ];
    mainProgram = "honomitv";
    platforms = platforms.unix;
  };
  passthru = {
    pythonVersion = python.pythonVersion;
  };
}
