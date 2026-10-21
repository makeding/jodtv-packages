{ pkgs, ... }:
let
  seed = import ../modules/honomitv/initial-config.nix { inherit (pkgs) lib coreutils; };
  first = pkgs.writeText "honomitv-initial.yaml" "encoder: FFmpeg\n";
  next = pkgs.writeText "honomitv-next.yaml" "encoder: QSVEncC\n";
in
{
  # Build the locked source distribution to catch missing legacy build backends.
  honomitv-pymediainfo = pkgs.runCommand "honomitv-pymediainfo" { } ''
    export PYTHONPATH=${pkgs.honomitv.pythonSet.pymediainfo}/${pkgs.python314.sitePackages}
    ${pkgs.python314.interpreter} -c 'import pymediainfo; from importlib.metadata import version; assert version("pymediainfo") == "6.1.0"'
    touch $out
  '';
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
