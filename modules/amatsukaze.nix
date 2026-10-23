{ config, lib, pkgs, ... }:
let
  cfg = config.services.amatsukaze;
in
{
  options.services.amatsukaze = {
    enable = lib.mkEnableOption "Amatsukaze transcoding server and WebUI";
    package = lib.mkPackageOption pkgs "amatsukaze" { };
    port = lib.mkOption {
      type = lib.types.ints.between 1 65534;
      default = 32768;
      description = "Server TCP port; the WebUI uses this port plus one.";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments for AmatsukazeServerCLI.";
    };
    path = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional tools and hardware encoders, such as pkgs.nvencc.";
    };
    mediaDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Absolute media/work directories the service may write to.";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the server and WebUI TCP ports.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "Amatsukaze's Linux release is only packaged for x86_64-linux.";
      }
      {
        assertion = builtins.all (path: lib.hasPrefix "/" path && !lib.hasInfix "\n" path) cfg.mediaDirectories;
        message = "services.amatsukaze.mediaDirectories must be absolute paths without newlines.";
      }
    ];
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.port (cfg.port + 1) ];
    users.users.amatsukaze = {
      isSystemUser = true;
      group = "amatsukaze";
      extraGroups = [ "video" "render" ];
    };
    users.groups.amatsukaze = { };
    systemd.services.amatsukaze = {
      description = "Amatsukaze transcoding server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = cfg.path;
      unitConfig.RequiresMountsFor = cfg.mediaDirectories;
      serviceConfig = {
        User = "amatsukaze";
        Group = "amatsukaze";
        StateDirectory = "amatsukaze";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/amatsukaze";
        ExecStart = lib.escapeShellArgs ([
          "${cfg.package}/bin/amatsukaze"
          "--state-dir" "/var/lib/amatsukaze"
          "server" "-p" (toString cfg.port)
        ] ++ cfg.extraArgs);
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStopSec = 120;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = cfg.mediaDirectories;
      };
    };
  };
}
