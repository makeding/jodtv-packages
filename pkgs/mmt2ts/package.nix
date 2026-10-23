{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "mmt2ts";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "Till0196";
    repo = "mmt2ts";
    tag = "v${finalAttrs.version}";
    hash = "sha256-F670vaw8DoGkMztATRWzbpsUpbS7fgByNUnd/GCHlOU=";
  };

  vendorHash = "sha256-EfVvGQ6V3YTph7oZArSaxx4Dq9k6+/zJMLQtNAG1QYM=";

  subPackages = [
    "cmd/mmt2ts"
    "cmd/ts2mmt"
    "cmd/mmtcut"
  ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
  ];

  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  postInstall = ''
    install -Dm644 LICENSE "$out/share/doc/mmt2ts/LICENSE"
    install -Dm644 NOTICE "$out/share/doc/mmt2ts/NOTICE"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    for command in mmt2ts ts2mmt mmtcut; do
      "$out/bin/$command" -version | grep -F 'v${finalAttrs.version} '
      # mmt2ts and ts2mmt propagate flag.ErrHelp as exit status 1.
      status=0
      "$out/bin/$command" -h > "$command-help.log" 2>&1 || status=$?
      test "$status" -le 1
      grep -E "Usage of (.*/)?$command:" "$command-help.log"
    done
    runHook postInstallCheck
  '';

  meta = {
    description = "MMT/TLV and MPEG-2 TS conversion, inspection and cutting tools";
    homepage = "https://github.com/Till0196/mmt2ts";
    license = lib.licenses.asl20;
    mainProgram = "mmt2ts";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = [ lib.maintainers.huggy ];
  };
})
