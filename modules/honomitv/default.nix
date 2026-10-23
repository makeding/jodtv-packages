{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.honomitv;
  format = pkgs.formats.yaml { };
  pythonVersion = cfg.package.passthru.pythonVersion or "3.11";

  # Merge encoder setting into config
  finalSettings = lib.recursiveUpdate cfg.settings {
    general = {
      encoder = cfg.encoder;
    };
  };

  configFile = format.generate "config.yaml" finalSettings;
  initialConfig = import ./initial-config.nix {
    inherit lib;
    inherit (pkgs) coreutils;
  };
in
{
  options.services.honomitv = {
    enable = lib.mkEnableOption "HonomiTV - Modern TV media server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.honomitv.override {
        qsvencc = if cfg.encoder == "QSVEncC" then pkgs.qsvencc else null;
        nvencc = if cfg.encoder == "NVEncC" then pkgs.nvencc else null;
      };
      defaultText = lib.literalExpression "pkgs.honomitv with the selected encoder";
      description = "HonomiTV package. The default includes only the hardware encoder selected by services.honomitv.encoder; explicit packages are used unchanged.";
    };

    encoder = lib.mkOption {
      type = lib.types.enum [
        "FFmpeg"
        "QSVEncC"
        "NVEncC"
      ];
      default = "FFmpeg";
      description = ''
        Hardware encoder included in the default package and written to the initial
        configuration. Existing config.yaml is preserved.

        - FFmpeg: Software encoder (CPU-based, works everywhere but slow)
        - QSVEncC: Intel Quick Sync Video (requires Intel CPU with integrated graphics)
        - NVEncC: NVIDIA NVENC (requires an NVIDIA GPU and driver)

        FFmpeg is always available. Changing the installed hardware backend requires
        a rebuild and a matching encoder setting in HonomiTV.
      '';
      example = "QSVEncC";
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        Initial configuration for HonomiTV, written only when config.yaml is absent.
        Existing files and changes saved by HonomiTV survive restarts and rebuilds.
        Firewall ports and directory access remain managed by Nix.
        See config.example.yaml in the source repository for available options.

        Note: general.encoder is automatically set from services.honomitv.encoder option.
      '';
      example = lib.literalExpression ''
        {
          general = {
            backend = "Mirakurun";
            mirakurun_url = "http://localhost:40772/";
            program_update_interval = 10.0;
            debug = false;
          };
          server = {
            port = 7000;
          };
          tv = {
            max_alive_time = 10;
          };
          video = {
            recorded_folders = [ "/var/lib/epgstation/recorded" ];
          };
          capture = {
            upload_folders = [ "/var/lib/honomitv/captures" ];
          };
        }
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/honomitv";
      description = ''
        Directory for storing HonomiTV data (database, thumbnails, etc.).
      '';
    };

    logsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/honomitv";
      description = ''
        Directory for storing HonomiTV logs.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "honomitv";
      description = ''
        User account under which HonomiTV runs.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "honomitv";
      description = ''
        Group under which HonomiTV runs.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the firewall for HonomiTV's port.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "HonomiTV service user";
      home = cfg.dataDir;
    };

    users.groups.${cfg.group} = { };

    systemd.services.honomitv = {
      description = "HonomiTV - Modern TV media server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        # Create necessary directories
        mkdir -p ${cfg.dataDir}
        mkdir -p ${cfg.logsDir}

        # Seed once; preserve configuration saved by the application.
        ${initialConfig configFile "${cfg.dataDir}/config.yaml"}

        # Create subdirectories in data dir (HONOMITV_DATA_DIR points to ./data)
        mkdir -p ${cfg.dataDir}/data/account-icons
        mkdir -p ${cfg.dataDir}/data/thumbnails

        # Create symlinks to Nix store files in working directory
        ln -sfn ${cfg.package}/lib/honomitv/app ${cfg.dataDir}/app
        ln -sfn ${cfg.package}/lib/honomitv/static ${cfg.dataDir}/static
        ln -sfn ${cfg.package}/lib/honomitv/thirdparty ${cfg.dataDir}/thirdparty
        ln -sfn ${cfg.package}/lib/honomitv/.venv ${cfg.dataDir}/.venv
        ln -sfn ${cfg.package}/lib/honomitv/KonomiTV.py ${cfg.dataDir}/KonomiTV.py
        ln -sfn ${cfg.package}/lib/honomitv/KonomiTV-Service.py ${cfg.dataDir}/KonomiTV-Service.py
        ln -sfn ${cfg.package}/lib/honomitv/pyproject.toml ${cfg.dataDir}/pyproject.toml
      '';

      environment = {
        HONOMITV_DATA_DIR = "${cfg.dataDir}/data";
        HONOMITV_LOGS_DIR = cfg.logsDir;
        HONOMITV_CONFIG_PATH = "${cfg.dataDir}/config.yaml";
        HONOMITV_WORK_DIR = cfg.dataDir;
        # Add Nix store path to PYTHONPATH so Python can find app modules
        PYTHONPATH = "${cfg.package}/lib/honomitv";
        # Add graphics drivers and Python packages bundled libraries to library path
        LD_LIBRARY_PATH = lib.concatStringsSep ":" (
          lib.optional (cfg.encoder == "QSVEncC") "${pkgs.intel-media-sdk-h}/lib"
          ++ [
            "${cfg.package}/lib/honomitv/.venv/lib/python${pythonVersion}/site-packages/av.libs"
            "${cfg.package}/lib/honomitv/.venv/lib/python${pythonVersion}/site-packages/opencv_python_headless.libs"
            "${cfg.package}/lib/honomitv/.venv/lib/python${pythonVersion}/site-packages/pillow.libs"
            "${cfg.package}/lib/honomitv/.venv/lib/python${pythonVersion}/site-packages/numpy.libs"
            "${cfg.package}/lib/honomitv/.venv/lib/python${pythonVersion}/site-packages/pyppmd.libs"
            "${pkgs.libxcb}/lib"
          ]
          ++ [
            (lib.makeSearchPathOutput "lib" "lib" config.hardware.graphics.extraPackages)
          ]
        );
      }
      // lib.optionalAttrs (cfg.encoder == "QSVEncC") {
        LIBVA_DRIVER_NAME = "iHD";
        ONEVPL_SEARCH_PATH = "${pkgs.intel-media-sdk-h}/lib";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${lib.getExe cfg.package}";
        Restart = "on-failure";
        RestartSec = "5s";
        WorkingDirectory = cfg.dataDir;

        # Add video and render groups for GPU access
        SupplementaryGroups = [
          "video"
          "render"
        ];

        # State and log directories
        StateDirectory = "honomitv";
        LogsDirectory = "honomitv";
        CacheDirectory = "honomitv";

        # Relaxed security settings to allow GPU access
        NoNewPrivileges = true;
        # Don't use ProtectSystem=strict as it prevents /dev/dri access
        ProtectHome = true;
        ReadWritePaths = lib.mkMerge [
          [
            cfg.dataDir
            "${cfg.dataDir}/data"
            cfg.logsDir
          ]
          # Allow read access to recorded video folders if configured
          (lib.optionals (cfg.settings ? video && cfg.settings.video ? recorded_folders) (
            map (folder: folder) cfg.settings.video.recorded_folders
          ))
          # Allow write access to capture upload folders if configured
          (lib.optionals (cfg.settings ? capture && cfg.settings.capture ? upload_folders) (
            map (folder: folder) cfg.settings.capture.upload_folders
          ))
        ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        LockPersonality = true;

        # GPU device access for hardware encoding
        DeviceAllow = [
          "/dev/dri rw"
          "char-drm rw"
        ];
        # Use 'auto' instead of 'closed' to allow access to allowed devices
        DevicePolicy = "auto";

        # Resource limits
        LimitNOFILE = 65536;
      };
    };

    # Ensure directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.logsDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data/account-icons 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data/thumbnails 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Open firewall if requested
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.settings.server.port ];
    };
  };
}
