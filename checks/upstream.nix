{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  linuxPkgs = import nixpkgs {
    system = "x86_64-linux";
    overlays = [ self.overlays.default ];
    config.allowUnfreePredicate = package: lib.getName package == "nvencc";
  };
  configOf =
    module:
    (lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;
          nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "nvencc";
        }
        module
      ];
    }).config;
  defaults = configOf { };
  selected = configOf {
    services.honomitv = {
      enable = true;
      package = linuxPkgs.konomitv;
    };
    dtv.epgstation = {
      enable = true;
      package = linuxPkgs.epgstation-upstream;
      settings.mirakurunPath = "http://tuner.example:40772";
    };
    services.epgstation.database.passwordFile = "/run/secrets/epgstation-db";
  };
  native = configOf {
    services.epgstation = {
      enable = true;
      package = linuxPkgs.epgstation-upstream;
      database.passwordFile = "/run/secrets/epgstation-db";
    };
  };
in
{
  upstream-package-selection =
    assert defaults.services.honomitv.package.src.rev == linuxPkgs.honomitv.src.rev;
    assert defaults.services.epgstation.package.src.rev == linuxPkgs.epgstation-h.src.rev;
    assert defaults.dtv.epgstation.package.src.rev == linuxPkgs.epgstation-h.src.rev;
    assert linuxPkgs.konomitv.src.rev != linuxPkgs.honomitv.src.rev;
    assert linuxPkgs.epgstation-upstream.src.rev != linuxPkgs.epgstation-h.src.rev;
    assert linuxPkgs.konomitv.pythonVersion == "3.13";
    assert linuxPkgs.honomitv.pythonVersion == "3.13";
    assert linuxPkgs.honomitv.nvenccForHost.outPath == linuxPkgs.nvencc.outPath;
    assert linuxPkgs.konomitv.nvenccForHost.outPath == linuxPkgs.nvencc.outPath;
    assert !(builtins.elem "NVEncC" linuxPkgs.honomitv.uncheckedTools);
    assert !(builtins.elem "NVEncC" linuxPkgs.konomitv.uncheckedTools);
    assert
      (linuxPkgs.honomitv.override { pythonInterpreter = linuxPkgs.python313; }).pythonVersion == "3.13";
    assert
      (linuxPkgs.konomitv.override { ffmpeg-headless = linuxPkgs.emptyDirectory; }).buildInputs
      != linuxPkgs.konomitv.buildInputs;
    assert selected.services.epgstation.package.src.rev == linuxPkgs.epgstation-upstream.src.rev;
    assert selected.systemd.services.honomitv.serviceConfig.ExecStart == lib.getExe linuxPkgs.konomitv;
    assert lib.hasInfix (builtins.unsafeDiscardStringContext "${linuxPkgs.konomitv}/lib/honomitv") (
      builtins.unsafeDiscardStringContext selected.systemd.services.honomitv.preStart
    );
    assert
      selected.systemd.services.honomitv.environment.PYTHONPATH == "${linuxPkgs.konomitv}/lib/honomitv";
    assert
      selected.systemd.services.epgstation.serviceConfig.ExecStart
      == "${linuxPkgs.epgstation-upstream}/bin/epgstation start";
    assert
      native.systemd.services.epgstation.serviceConfig.ExecStart
      == "${linuxPkgs.epgstation-upstream}/bin/epgstation start";
    assert !(selected.systemd.services ? epgstation-epg-update);
    assert builtins.all (item: item.assertion) selected.assertions;
    pkgs.runCommand "upstream-package-selection" { } "touch $out";
  konomitv-build = pkgs.runCommand "konomitv-build" { } ''
    ${pkgs.konomitv.pythonEnv}/bin/python - <<'PYTHON'
    import fastapi
    import tortoise
    import pyppmd
    import av
    payload = b"KonomiTV dependency smoke test" * 100
    assert pyppmd.decompress(pyppmd.compress(payload)) == payload
    PYTHON
    test -s ${pkgs.konomitv.frontend}/share/honomitv/index.html
    ${pkgs.konomitv}/bin/konomitv --help > help.txt
    test -s help.txt
    touch $out
  '';
}
