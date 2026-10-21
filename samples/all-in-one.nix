# Mirakurun + EPGStation + HonomiTV, with one PT3 and a CCID reader.
{ ... }:
{
  dtv = {
    tuners = [ { driver = "pt3"; } ];
    channels = builtins.fromJSON (builtins.readFile ./channels.json);
    card.enable = true;
    # card.rw5100Support = true;
    mirakurun.enable = true;
    epgstation = {
      enable = true;
      listen.port = 20772;
      openFirewall = true;
      settings.recorded = [
        {
          name = "recorded";
          path = "/var/lib/epgstation/recorded";
        }
      ];
    };
  };

  # Provision this file at runtime, for example with sops-nix or agenix.
  services.epgstation.database.passwordFile = "/run/secrets/epgstation-db-password";
  systemd.services.epgstation.serviceConfig.UMask = "0027";

  services.honomitv = {
    enable = true;
    encoder = "FFmpeg";
    openFirewall = true;
    # Initial configuration only; later edits made by HonomiTV are preserved.
    settings = {
      general = {
        backend = "Mirakurun";
        mirakurun_url = "http://127.0.0.1:40772/";
      };
      server.port = 7000;
      video.recorded_folders = [ "/var/lib/epgstation/recorded" ];
      capture.upload_folders = [ "/var/lib/honomitv/captures" ];
    };
  };
  users.users.honomitv.extraGroups = [ "epgstation" ];
  systemd.tmpfiles.rules = [
    "d /var/lib/honomitv/captures 0750 honomitv honomitv -"
  ];
  systemd.services.honomitv = {
    after = [
      "mirakurun.service"
      "epgstation.service"
    ];
    wants = [
      "mirakurun.service"
      "epgstation.service"
    ];
  };
}
