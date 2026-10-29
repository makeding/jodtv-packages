{ pkgs, ... }:
let
  seed = import ../modules/honomitv/initial-config.nix { inherit (pkgs) lib coreutils; };
  first = pkgs.writeText "honomitv-initial.yaml" "encoder: FFmpeg\n";
  next = pkgs.writeText "honomitv-next.yaml" "encoder: QSVEncC\n";
in
assert
  pkgs.stdenv.hostPlatform.system != "aarch64-linux"
  || (
    pkgs.honomitv.qsvenccForHost == null
    && pkgs.honomitv.nvenccForHost == null
    && pkgs.konomitv.qsvenccForHost == null
    && pkgs.konomitv.nvenccForHost == null
  );
{
  # Build the locked source distribution to catch missing legacy build backends.
  honomitv-pymediainfo = pkgs.runCommand "honomitv-pymediainfo" { } ''
    export PYTHONPATH=${pkgs.honomitv.pythonSet.pymediainfo}/${pkgs.python313.sitePackages}
    ${pkgs.python313.interpreter} -c 'import pymediainfo; from importlib.metadata import version; assert version("pymediainfo") == "6.1.0"'
    touch $out
  '';
  honomitv-build = pkgs.runCommand "honomitv-build" { } ''
    ${pkgs.honomitv.pythonEnv}/bin/python - <<'PYTHON'
    import pyppmd
    import py7zr
    import fastapi
    import tortoise
    import pymediainfo
    from importlib.metadata import version

    assert version("pyppmd") == "1.1.1"
    assert version("pymediainfo") == "6.1.0"
    payload = b"HonomiTV dependency smoke test" * 100
    assert pyppmd.decompress(pyppmd.compress(payload)) == payload
    PYTHON
    test -s ${pkgs.honomitv.frontend}/share/honomitv/index.html
    ${pkgs.honomitv}/bin/honomitv --help > help.txt
    test -s help.txt
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
