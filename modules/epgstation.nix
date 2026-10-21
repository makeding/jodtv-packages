{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.epgstation;
  externalUpdater = (cfg.settings.epgUpdaterMode or "fork") == "external";
in

{
  config = lib.mkIf (cfg.enable && externalUpdater) {
    systemd.services.epgstation-epg-update = {
      description = "Update EPGStation EPG once";
      wants = [
        "network-online.target"
        "mirakurun.service"
        "mysql.service"
      ];
      after = [
        "network-online.target"
        "mirakurun.service"
        "mysql.service"
      ];
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
  };
}
