{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule {
  pname = "hiraku";
  version = "0-unstable-2026-08-13";

  src = fetchFromGitHub {
    owner = "makeding";
    repo = "Hiraku";
    rev = "e96bc97385ec14c3cc2a5dbdc2d740693be4a967";
    hash = "sha256-nvgSVVOMkaXUhfi2+ENyOYtJFE/JDLIL9Ox1V0oVFs0=";
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
    # The pinned source does not include a license grant.
    license = licenses.unfree;
    mainProgram = "hiraku";
    platforms = platforms.unix;
    maintainers = [ lib.maintainers.huggy ];
  };
}
