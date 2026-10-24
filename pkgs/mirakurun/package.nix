{
  lib,
  stdenv,
  bash,
  buildNpmPackage,
  fetchFromGitHub,
  installShellFiles,
  makeWrapper,
  nodejs,
  replaceVars,
  v4l-utils,
  which,
}:

buildNpmPackage rec {
  pname = "mirakurun";
  version = "4.1.5-unstable-2026-10-24";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "Mirakurun";
    rev = "93b757f4e4f38d4e1ebdb6644ace48f5b58cc0b0";
    sha256 = "sha256-g3ITeGCVVg9AL4Zx9NO5WjHW6JfRz/eym6CwzeHqLZQ=";
  };

  postUnpack = ''
    rm source/tslint.json
    sed -i 's|/usr/local||g' source/processes.json
    # sed -i '/\.yml", path);/a fs.chmodSync(path, 0o644);' source/src/Mirakurun/config.ts
  '';

  npmDepsHash = "sha256-QZu2yx+hoLM5inwoJZ7ubA19gqvjbaggb2367zhuvEY=";

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  # workaround for https://github.com/webpack/webpack/issues/14532
  NODE_OPTIONS = "--openssl-legacy-provider";

  postInstall =
    let
      runtimeDeps = [
        bash
        nodejs
        which
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [ v4l-utils ];
      crc32Patch = replaceVars ./fix-musl-detection.patch {
        isMusl = if stdenv.hostPlatform.isMusl then "true" else "false";
      };
    in
    ''
      sed 's/@DESCRIPTION@/${meta.description}/g' ${./mirakurun.1} > mirakurun.1
      installManPage mirakurun.1

      wrapProgram $out/bin/mirakurun-epgdump \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}

      # XXX: The original mirakurun command uses PM2 to manage the Mirakurun
      # server.  However, we invoke the server directly and let systemd
      # manage it to avoid complication. This is okay since no features
      # unique to PM2 is currently being used.
      makeWrapper ${nodejs}/bin/npm $out/bin/mirakurun \
        --chdir "$out/lib/node_modules/mirakurun" \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}

      pushd $out/lib/node_modules/mirakurun/node_modules/@node-rs/crc32
      patch -p3 < ${crc32Patch}
      popd
    '';

  meta = with lib; {
    description = "A Japanese digital TV tuner API server specifically designed for \"Air\"";
    license = licenses.asl20;
    maintainers = [ lib.maintainers.huggy ];
  };
}
