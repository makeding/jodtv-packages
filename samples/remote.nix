# Frontend role: consume the four modes exported by hirakud.nix.
{ ... }:
{
  dtv = {
    mirakurun.enable = true;
    channels = builtins.fromJSON (builtins.readFile ./channels.json);
    tuners =
      map
        (tuner: {
          driver = "hiraku";
          inherit (tuner) name mode;
          hiraku = {
            address = "tuner.example:40773";
            secret = "replace-with-a-shared-token";
            mode = tuner.name;
          };
        })
        [
          {
            name = "PT3-T1";
            mode = [ "GR" ];
          }
          {
            name = "PT3-T2";
            mode = [ "GR" ];
          }
          {
            name = "PT3-S1";
            mode = [
              "BS"
              "CS"
            ];
          }
          {
            name = "PT3-S2";
            mode = [
              "BS"
              "CS"
            ];
          }
        ];
  };
}
