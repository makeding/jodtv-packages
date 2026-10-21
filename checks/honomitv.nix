{ pkgs, ... }:
let
  seed = import ../modules/honomitv/initial-config.nix { inherit (pkgs) lib coreutils; };
  first = pkgs.writeText "honomitv-initial.yaml" "encoder: FFmpeg\n";
  next = pkgs.writeText "honomitv-next.yaml" "encoder: QSVEncC\n";
in
{
  honomitv-initial-config = pkgs.runCommand "honomitv-initial-config" { } ''
    ${seed first "config.yaml"}
    cmp ${first} config.yaml
    test "$(${pkgs.coreutils}/bin/stat -c %a config.yaml)" = 640

    printf 'encoder: application-edit\n' > config.yaml
    cp config.yaml expected.yaml
    ${seed next "config.yaml"}
    cmp expected.yaml config.yaml

    : > empty.yaml
    ${seed first "empty.yaml"}
    test ! -s empty.yaml

    ln -s missing.yaml linked.yaml
    ${seed first "linked.yaml"}
    test -L linked.yaml
    test ! -e missing.yaml
    touch $out
  '';
}
