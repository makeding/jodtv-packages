{ lib, coreutils }:
source: target:
let
  destination = lib.escapeShellArg target;
in
''
  if [ ! -e ${destination} ] && [ ! -L ${destination} ]; then
    ${coreutils}/bin/install -m 0640 ${lib.escapeShellArg (toString source)} ${destination}
  fi
''
