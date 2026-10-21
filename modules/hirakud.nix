{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hirakud;
  format = pkgs.formats.json { };
  configFile = format.generate "hiraku.json" cfg.settings;
in
{
  options.services.hirakud = {
    enable = lib.mkEnableOption "Hiraku command relay agent";

    package = lib.mkPackageOption pkgs "hiraku" { };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      description = "Hirakud configuration serialized as JSON.";
    };

    path = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Packages containing commands referenced by Hiraku templates.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the Hirakud TCP port in the firewall.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 40773;
      description = "Hirakud TCP port used for the firewall rule.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;

    systemd.services.hirakud = {
      description = "Hiraku command relay agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = cfg.path;
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/hirakud -config ${configFile}";
        Restart = "always";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };
  };
}
