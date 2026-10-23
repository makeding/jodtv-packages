{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  configOf = module: (lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.packages
      self.nixosModules.dtv
      {
        system.stateVersion = "26.05";
        boot.isContainer = true;
        dtv.mirakurun.enable = true;
        # Execute the generated credential script on the check host.
        nixpkgs.overlays = [ (_final: _prev: { inherit (pkgs) openssl; }) ];
      }
      module
    ];
  }).config;
  disabled = configOf { };
  enabled = configOf { dtv.epgstation.enable = true; };
  existing = configOf {
    dtv.epgstation.enable = true;
    services.epgstation.database = {
      name = "existing-epg";
      passwordFile = "/run/secrets/epgstation-db";
    };
    services.mysql.settings.mysqld.bind-address = "192.0.2.10";
  };
  initialize = lib.replaceStrings
    [ enabled.services.epgstation.database.passwordFile ]
    [ "\"$PWD/password\"" ]
    enabled.system.activationScripts.epgstationDatabasePassword.text;
in
{
  epgstation-bootstrap =
    assert !disabled.services.mysql.enable;
    assert !(disabled.system.activationScripts ? epgstationDatabasePassword);
    assert enabled.services.mysql.enable;
    assert enabled.services.mysql.ensureDatabases == [ "epgstation" ];
    assert enabled.services.mysql.initialDatabases == [ ];
    assert enabled.services.mysql.settings.mysqld.bind-address == "127.0.0.1";
    assert enabled.services.epgstation.database.passwordFile == "/var/lib/epgstation-db-password";
    assert enabled.services.epgstation.settings.mysql.password == "@dbPassword@";
    assert enabled.services.epgstation.settings.port == 20772;
    assert enabled.services.epgstation.settings.socketioPort == 20773;
    assert builtins.elem "mirakurun.service" enabled.systemd.services.epgstation.after;
    assert builtins.elem "mysql.service" enabled.systemd.services.epgstation.after;
    assert existing.services.epgstation.database.passwordFile == "/run/secrets/epgstation-db";
    assert existing.services.mysql.ensureDatabases == [ "existing-epg" ];
    assert existing.services.mysql.settings.mysqld.bind-address == "192.0.2.10";
    assert !(existing.system.activationScripts ? epgstationDatabasePassword);
    pkgs.runCommand "epgstation-bootstrap" { } ''
      umask 022
      ${initialize}
      test -s password
      test "$(stat -c %a password)" = 600
      test "$(wc -c < password)" = 65
      cp password previous-password
      ${initialize}
      cmp password previous-password
      # A pre-existing external value must also survive activation unchanged.
      printf 'existing-password\n' > password
      ${initialize}
      test "$(cat password)" = existing-password
      touch $out
    '';
}
