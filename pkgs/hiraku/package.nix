{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule {
  pname = "hiraku";
  version = "0-unstable-2026-10-21";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "Hiraku";
    rev = "bd802a010a4ad4ebebe89d0546ffce6faa712523";
    hash = "sha256-k6ngXk8fsnbyV9Yt64m5nH1SFN2f9utMtG3EnHRO7kY=";
  };

  subPackages = [
    "cmd/hiraku"
    "cmd/hirakud"
  ];

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Small command relay agent for exposing selected local command templates over TCP";
    homepage = "https://github.com/makeding/Hiraku";
    license = licenses.mit;
    mainProgram = "hiraku";
    platforms = platforms.unix;
    maintainers = [ lib.maintainers.huggy ];
  };
}
