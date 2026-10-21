# Capture role: export four PT3 inputs without running Mirakurun.
{ ... }:
{
  dtv = {
    tuners = [ { driver = "pt3"; } ];
    channels = builtins.fromJSON (builtins.readFile ./channels.json);
    card.enable = true;
    hirakud = {
      enable = true;
      listen = "0.0.0.0:40773";
      openFirewall = true;
      settings.secret = "replace-with-a-shared-token";
    };
  };
}
