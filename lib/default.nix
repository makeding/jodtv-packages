{ lib }:
{
  mkHirakuTuners =
    {
      tuners,
      address,
      secret,
      namePrefix ? "",
    }:
    map (t: {
      driver = "hiraku";
      name = "${namePrefix}${t.name}";
      inherit (t) mode;
      hiraku = {
        inherit address secret;
        inherit (t.hiraku) mode modeBS4K;
      };
    }) tuners;
  mkRemoteTuners =
    {
      tuners,
      host,
      port ? 40772,
      decoder ? true,
      namePrefix ? "",
    }:
    map (t: {
      driver = "remote";
      name = "${namePrefix}${t.name}";
      inherit (t) mode;
      remote = { inherit host port decoder; };
    }) tuners;
}
