{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  configOf =
    module:
    (lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.packages
        self.nixosModules.casproxyserver
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;
        }
        module
      ];
    }).config;
  disabled = configOf { };
  enabled = configOf {
    # Generate the actual service YAML on the check host.
    nixpkgs.overlays = [ (_final: _prev: { inherit (pkgs) formats; }) ];
    services.casproxyserver = {
      enable = true;
      openFirewall = true;
      advertiseAddress = "proxy.example";
      settings = {
        listenIp = "0.0.0.0";
        port = 24001;
        allowedIps = [ "192.0.2.0/24" ];
      };
    };
    services.pcscd.extraArgs = [ "--debug" ];
  };
  polkit = configOf {
    services.casproxyserver.enable = true;
    security.polkit.enable = true;
  };
  replacement = pkgs.writeShellScriptBin "casproxyserver" "exit 0";
  overridden = configOf {
    services.casproxyserver = {
      enable = true;
      package = replacement;
      keepPcscdRunning = false;
    };
  };
  epg =
    (lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.packages
        self.nixosModules.epgstation
        {
          system.stateVersion = "26.05";
          boot.isContainer = true;
          services.epgstation = {
            enable = true;
            database.passwordFile = "/run/secrets/epgstation-db";
          };
          services.mysql.settings.mysqld.bind-address = "127.0.0.1";
        }
      ];
    }).config;
in
{
  casproxyserver =
    assert !disabled.services.pcscd.enable;
    assert !(disabled.systemd.services ? casproxyserver);
    assert disabled.services.casproxyserver.endpoint == null;
    assert enabled.services.casproxyserver.endpoint == "proxy.example:24001";
    assert enabled.services.pcscd.enable;
    assert builtins.elem 24001 enabled.networking.firewall.allowedTCPPorts;
    assert !(builtins.elem 24000 overridden.networking.firewall.allowedTCPPorts);
    assert builtins.elem "pcscd.service" enabled.systemd.services.casproxyserver.after;
    assert builtins.elem "pcscd.service" enabled.systemd.services.casproxyserver.wants;
    assert enabled.systemd.services.casproxyserver.serviceConfig.DynamicUser;
    assert enabled.systemd.services.casproxyserver.serviceConfig.SupplementaryGroups == [ "pcscd" ];
    assert enabled.systemd.services.casproxyserver.serviceConfig.ProtectSystem == "strict";
    assert
      enabled.systemd.services.pcscd.serviceConfig.ExecStart == [
        ""
        "${lib.getExe enabled.services.pcscd.package} -f -c /etc/reader.conf --debug"
      ];
    assert lib.hasInfix (builtins.unsafeDiscardStringContext (lib.getExe polkit.services.pcscd.package)) (
      builtins.elemAt polkit.systemd.services.pcscd.serviceConfig.ExecStart 1
    );
    assert lib.hasInfix " -x " (
      builtins.elemAt overridden.systemd.services.pcscd.serviceConfig.ExecStart 1
    );
    assert
      overridden.systemd.services.casproxyserver.serviceConfig.ExecStart
      == "${lib.getExe replacement} /etc/casproxyserver.yml";
    assert builtins.all (a: a.assertion) enabled.assertions;
    assert epg.services.mysql.enable;
    assert epg.services.mysql.ensureDatabases == [ "epgstation" ];
    assert epg.services.mysql.initialDatabases == [ ];
    assert epg.services.mysql.dataDir == "/var/lib/mysql";
    assert epg.services.epgstation.settings.mysql.socketPath == "/run/mysqld/mysqld.sock";
    assert builtins.elem "mysql.service" epg.systemd.services.epgstation.after;
    pkgs.runCommand "casproxyserver-module" { } ''
      grep -Fx 'listenIp: 0.0.0.0' ${enabled.environment.etc."casproxyserver.yml".source}
      grep -Fx 'port: 24001' ${enabled.environment.etc."casproxyserver.yml".source}
      grep -F '192.0.2.0/24' ${enabled.environment.etc."casproxyserver.yml".source}
      touch $out
    '';
}
