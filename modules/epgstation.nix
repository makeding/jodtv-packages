{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.epgstation;
  databasePasswordFile = "/var/lib/epgstation-db-password";
  externalUpdater = (cfg.settings.epgUpdaterMode or "fork") == "external";
in

{
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.epgstation.database.passwordFile = lib.mkDefault databasePasswordFile;
      # Keep the original EPGStation HTTP port.  The upstream module derives
      # Socket.IO and client Socket.IO ports from this setting.
      services.epgstation.settings.port = lib.mkDefault 8888;
      services.mysql.settings.mysqld.bind-address = lib.mkDefault "127.0.0.1";
      system.activationScripts.epgstationDatabasePassword =
        lib.mkIf (cfg.database.passwordFile == databasePasswordFile)
          {
            text = ''
              if [ ! -e ${databasePasswordFile} ]; then
                (umask 077; ${pkgs.openssl}/bin/openssl rand -hex 32 > ${databasePasswordFile})
              fi
            '';
          };
    })
    (lib.mkIf (cfg.enable && externalUpdater) {
      systemd.services.epgstation-epg-update = {
        description = "Update EPGStation EPG once";
        wants = [
          "network-online.target"
          "mysql.service"
        ]
        ++ lib.optional config.services.mirakurun.enable "mirakurun.service";
        after = [
          "network-online.target"
          "mysql.service"
        ]
        ++ lib.optional config.services.mirakurun.enable "mirakurun.service";
        environment.NODE_ENV = "production";

        serviceConfig = {
          Type = "exec";
          User = "epgstation";
          Group = "epgstation";
          ExecStart = "-${lib.getExe cfg.package} run epg:update";
        };
      };

      systemd.services.epgstation = {
        wants = [ "epgstation-epg-update.service" ];
      };

      systemd.timers.epgstation-epg-update = {
        description = "Update EPGStation EPG periodically";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "${toString (cfg.settings.epgUpdateIntervalTime or 10)}min";
          Persistent = true;
          Unit = "epgstation-epg-update.service";
        };
      };
    })
  ];
}
