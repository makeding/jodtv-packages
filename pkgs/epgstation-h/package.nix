{
  lib,
  fetchpatch,
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
  version = "2.10.1-huggy-20261013";
  src = fetchFromGitHub {
    owner = "makeding";
    repo = "EPGStation";
    rev = "41b171056f3091b2868887d45f363bacb4e5aef9";
    sha256 = "sha256-PIk3ie4shw3s62f9Rc+K+PjBI0b7Aq9kontgCPQEous=";
  };

  nodejs = nodejs_24;

  #  makeCacheWritable = true;
  npmDepsHash = "sha256-uiivzfk9sANSiTYHzZpcNgxgVA6Kh1UO+Nkcq74bSH0=";
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
      installPhase
      meta
      nodejs
      ;
    patches = [ ./fix-client-eslint-config.patch ];
    npmDepsHash = "sha256-EFjrA25nKFDRVWbJOQRjE5FUvai6mEUA62I10MK8Swg=";
    npmFlags = [ "--legacy-peer-deps" ];
    npmRootPath = "";
    makeCacheWritable = true;
    sourceRoot = "${src.name}/client";

    NODE_OPTIONS = "--openssl-legacy-provider";
  };

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
  meta = with lib; {
    description = "Mirakurun を使用した録画管理ソフト";
    homepage = "https://github.com/l3tnun/EPGStation";
    license = licenses.mit;
    maintainers = [ lib.maintainers.huggy ];
    mainProgram = "epgstation";
  };
}
