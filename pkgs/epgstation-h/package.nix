{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  installShellFiles,
  makeWrapper,
  bash,
  ffmpeg-headless,
  nodejs_24,
  python3,
  tsreplace,
}:

buildNpmPackage rec {
  pname = "epgstation";
  version = "3.0.0-beta2-unstable-2026-10-22";
  src = fetchFromGitHub {
    owner = "makeding";
    repo = "EPGStation";
    rev = "85712b6a79efb345d52f6b35e2e06cd55bff5e6c";
    sha256 = "sha256-ly7xcUNv2CqKfuyq39dOrFwwzp1y2rfakamsJMp6SCM=";
  };

  nodejs = nodejs_24;

  #  makeCacheWritable = true;
  npmDepsHash = "sha256-dBqcxTfpgqvy0jE6cmsu+1h+gCJRJYLK9nypIOTUsZA=";
  npmBuildScript = "build-server";
  npmRootPath = "/lib/node_modules/epgstation";

  buildInputs = [ bash ];
  nativeBuildInputs = [
    installShellFiles
    makeWrapper
    python3
  ];
  clientDir = buildNpmPackage {
    pname = "${pname}-client";
    inherit
      version
      src
      meta
      nodejs
      ;
    npmDepsHash = "sha256-NPVpmcunFihkDn7qP+wdvKJuGrF4c3C9ldsTprh32wM=";
    makeCacheWritable = true;
    sourceRoot = "${src.name}/client";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/dist
      cp -r dist/. $out/dist/
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      test -s $out/dist/index.html
      test -d $out/dist/assets
    '';
  };

  passthru = { inherit clientDir; };

  postBuild = ''
    rm -rf client
    cp -r ${clientDir} client
  '';
  makeCacheWritable = true;
  installPhase = ''
    runHook preInstall
    npm prune --omit dev --no-save \
      $npmInstallFlags \
      "''${npmInstallFlagsArray[@]}" \
      $npmFlags \
      "''${npmFlagsArray[@]}"

    mkdir -p $out$npmRootPath
    cp -r . $out$npmRootPath

    runHook postInstall
  '';

  postInstall =
    let
      runtimeDeps = [
        nodejs
        bash
        ffmpeg-headless
        tsreplace
      ];
    in
    ''
      mkdir -p $out/{bin,libexec,share/doc/epgstation}

      pushd $out$npmRootPath

      mv config/enc.js.template $out/libexec/enc.js
      # The standalone encoder lives outside the application's ESM package scope.
      echo '{"type":"module"}' > $out/libexec/package.json
      mv LICENSE Readme.md $out/share/doc/epgstation
      mv doc/* $out/share/doc/epgstation
      sed 's/@DESCRIPTION@/${meta.description}/g' ${./epgstation.1} > doc/epgstation.1
      installManPage doc/epgstation.1
      rm -rf doc

      # just log to stdout and let journald do its job
      rm -rf logs

      # Replace the existing configuration and runtime state directories with
      # symlinks. Without this, they would all be non-writable because they
      # reside in the Nix store. Note that the source path won't be accessible
      # at build time.
      rm -r config data drop recorded thumbnail src/db/subscribers src/db/migrations
      ln -sfT /etc/epgstation config
      ln -sfT /var/lib/epgstation data
      ln -sfT /var/lib/epgstation/drop drop
      ln -sfT /var/lib/epgstation/recorded recorded
      ln -sfT /var/lib/epgstation/thumbnail thumbnail
      ln -sfT /var/lib/epgstation/db/subscribers src/db/subscribers
      ln -sfT /var/lib/epgstation/db/migrations src/db/migrations

      makeWrapper ${nodejs}/bin/npm $out/bin/epgstation \
       --chdir $out$npmRootPath \
       --prefix PATH : ${lib.makeBinPath runtimeDeps} \
       --set APP_ROOT_PATH $out$npmRootPath

      popd
    '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -s $out$npmRootPath/client/dist/index.html
    test -s $out$npmRootPath/dist/db/entities/EncodeQueue.js
    ${nodejs}/bin/node --check $out/libexec/enc.js
    cd $out$npmRootPath
    ${nodejs}/bin/node --input-type=module -e '
      import Database from "better-sqlite3";
      import "fs-ext";
      import "./dist/model/tuner/TunerServerAccessModel.js";
      const db = new Database(":memory:");
      db.close();
    '
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Mirakurun を使用した録画管理ソフト";
    homepage = "https://github.com/l3tnun/EPGStation";
    license = licenses.mit;
    maintainers = [ lib.maintainers.huggy ];
    mainProgram = "epgstation";
  };
}
