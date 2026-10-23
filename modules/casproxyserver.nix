{ config, lib, pkgs, ... }:
let
  cfg = config.services.casproxyserver;
  format = pkgs.formats.yaml { };
in
{
  options.services.casproxyserver = {
    enable = lib.mkEnableOption "PC/SC smart-card proxy server";
    package = lib.mkPackageOption pkgs "casproxyserver" { };
    openFirewall = lib.mkEnableOption "opening the CAS proxy TCP port";
    advertiseAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if cfg.settings.listenIp == "0.0.0.0" then null else cfg.settings.listenIp;
      defaultText = lib.literalExpression "settings.listenIp, or null for a wildcard listener";
      description = "Address reachable by clients; required to export a wildcard listener.";
    };
    endpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default =
        if !cfg.enable then null
        else if cfg.advertiseAddress == null || cfg.advertiseAddress == "" || cfg.advertiseAddress == "0.0.0.0" then
          throw "Set services.casproxyserver.advertiseAddress to a reachable address before referencing its endpoint."
        else "${cfg.advertiseAddress}:${toString cfg.settings.port}";
      description = "Exported client endpoint, or null when the service is disabled.";
    };
    keepPcscdRunning = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Keep pcscd running between clients to avoid repeated reader initialization.";
    };
    settings = lib.mkOption {
      default = { };
      description = "Public casproxyserver YAML configuration.";
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          listenIp = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "IPv4 address on which the proxy listens.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 24000;
            description = "CAS proxy TCP port.";
          };
          allowedIps = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "127.0.0.1/32" ];
            description = "Client IPv4 addresses or CIDR networks allowed by the proxy.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.pcscd.enable = true;
    environment.systemPackages = [ cfg.package ];
    environment.etc."casproxyserver.yml".source = format.generate "casproxyserver.yml" cfg.settings;
    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.settings.port;

    systemd.services.casproxyserver = {
      description = "PC/SC smart card proxy server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "pcscd.service" ];
      wants = [ "network-online.target" "pcscd.service" ];
      restartTriggers = [ config.environment.etc."casproxyserver.yml".source ];
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} /etc/casproxyserver.yml";
        Restart = "always";
        RestartSec = "5s";
        DynamicUser = true;
        SupplementaryGroups = [ "pcscd" ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
      };
    };

    systemd.services.pcscd.serviceConfig.ExecStart = lib.mkIf cfg.keepPcscdRunning (
      lib.mkForce [
        ""
        "${lib.getExe config.services.pcscd.package} -f -c /etc/reader.conf ${lib.escapeShellArgs config.services.pcscd.extraArgs}"
      ]
    );
  };
}
