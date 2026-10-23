{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.edcb-wine;
  stateDir = cfg.stateDir;
  edcbDir = "${stateDir}/EDCB";
  homeDir = "${stateDir}/home";
  winePrefix = "${stateDir}/wineprefix";
  storage = lib.unique (
    [
      cfg.recordingDir
      cfg.recordingInfoDir
    ]
    ++ cfg.recordingDirectories
  );
  startScript = import ./runtime.nix {
    inherit
      pkgs
      lib
      stateDir
      edcbDir
      homeDir
      winePrefix
      ;
    inherit (cfg)
      wine
      display
      recordingDir
      recordingInfoDir
      ;
    edcbTemplate = cfg.package;
    edcbWineSrc = cfg.package.edcbWineSrc;
    edcbWinDir = "Z:${lib.replaceStrings [ "/" ] [ "\\" ] edcbDir}";
    desktopSize = "${toString cfg.desktop.width}x${toString cfg.desktop.height}";
    desktopWidth = cfg.desktop.width;
    mirakcHost = cfg.backend.host;
    mirakcPort = cfg.backend.port;
    vncPort = cfg.vnc.port;
    vncListenAddress = cfg.vnc.listenAddress;
    bootstrapVersion = "3";
    quickLauncherWidth = 360;
    toolbarMargin = 12;
    traySize = 26;
    trayGap = 8;
    notoSansCjk = "${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc";
  };
in
{
  options.services.edcb-wine = {
    enable = lib.mkEnableOption "EDCB under Wine with an Xvfb/VNC desktop";
    package = lib.mkPackageOption pkgs "edcb-wine" { };
    wine = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wineWow64Packages.stable;
      defaultText = lib.literalExpression "pkgs.wineWow64Packages.stable";
      description = "Wine runtime providing wine, wineserver, wineboot and regedit.";
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/edcb-wine";
      description = "Persistent application state and Wine prefix directory.";
    };
    recordingDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/TV-Record";
      description = "Initial recording destination; subsequent changes are managed in EDCB.";
    };
    recordingInfoDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/TV-RecordInfo";
      description = "Initial recording metadata destination.";
    };
    recordingDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional writable recording destinations configured in EDCB.";
    };
    backend = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Mirakurun or mirakc host used by BonDriver_mirakc.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 40772;
        description = "Mirakurun or mirakc TCP port.";
      };
    };
    display = lib.mkOption {
      type = lib.types.str;
      default = ":88";
      description = "Private Xvfb display.";
    };
    desktop = {
      width = lib.mkOption {
        type = lib.types.ints.positive;
        default = 800;
        description = "Desktop width in pixels.";
      };
      height = lib.mkOption {
        type = lib.types.ints.positive;
        default = 900;
        description = "Desktop height in pixels.";
      };
    };
    vnc = {
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "VNC bind address. This session has no password; use a tunnel or a trusted network.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 5900;
        description = "VNC TCP port.";
      };
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open EDCB control/WebUI ports and VNC when it listens beyond loopback.";
    };
    tcpPort = lib.mkOption {
      type = lib.types.port;
      default = 4510;
      description = "Firewall port for EDCB control; keep aligned with EDCB's TCPPort setting.";
    };
    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 5510;
      description = "Firewall port for EMWUI; keep aligned with EDCB's HttpPort setting.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "EDCB-Wine requires x86_64-linux.";
      }
      {
        assertion = builtins.all (path: builtins.match "/[A-Za-z0-9_./-]+" path != null) (
          [ stateDir ] ++ storage
        );
        message = "EDCB-Wine state and recording directories must be absolute paths using letters, digits, _, ., / and -.";
      }
    ];
    users.groups.edcb-wine = { };
    users.users.edcb-wine = {
      isSystemUser = true;
      group = "edcb-wine";
      home = homeDir;
    };
    systemd.tmpfiles.rules = map (path: "d ${path} 0750 edcb-wine edcb-wine -") (
      [
        stateDir
        edcbDir
        homeDir
        winePrefix
        "${stateDir}/fontconfig-cache"
      ]
      ++ storage
    );
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall (
      [
        cfg.tcpPort
        cfg.httpPort
      ]
      ++ lib.optional (
        !(builtins.elem cfg.vnc.listenAddress [
          "127.0.0.1"
          "::1"
          "localhost"
        ])
      ) cfg.vnc.port
    );
    systemd.services.edcb-wine = {
      description = "EDCB running under Wine with Xvfb/VNC";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "local-fs.target"
        "network-online.target"
      ];
      unitConfig.RequiresMountsFor = [ stateDir ] ++ storage;
      path = [
        pkgs.coreutils
        pkgs.fontconfig
        pkgs.gnused
        pkgs.openbox
        pkgs.tk
        pkgs.x11vnc
        pkgs.xorg-server
        pkgs.xset
        cfg.wine
      ];
      serviceConfig = {
        Type = "simple";
        User = "edcb-wine";
        Group = "edcb-wine";
        WorkingDirectory = stateDir;
        ExecStart = startScript;
        Restart = "always";
        RestartSec = "5s";
        TimeoutStopSec = "30s";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        CapabilityBoundingSet = "";
        ReadWritePaths = [ stateDir ] ++ storage;
      };
    };
  };
}
