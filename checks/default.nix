{
  self,
  nixpkgs,
  pkgs,
}:
let
  lib = nixpkgs.lib;
  public = import ../pkgs {
    inherit (pkgs) callPackage;
    inputs = self.inputs;
  };
  marker = pkgs.emptyDirectory;
  recorderInputs = p: map (input: input.outPath) p.nativeBuildInputs;
  hasInput = p: input: builtins.elem input.outPath (recorderInputs p);
  injectable =
    builtins.all
      (
        name:
        hasInput public.${name} pkgs.libaribb25
        && hasInput (public.${name}.override { libaribb25 = marker; }) marker
        && !(hasInput (public.${name}.override { libaribb25 = marker; }) pkgs.libaribb25)
      )
      [
        "recpt1"
        "recdvb"
      ];
in
{
  dependency-injection =
    assert injectable;
    pkgs.runCommand "jodtv-packages-dependency-injection" { } "touch $out";
}
// import ./dtv.nix { inherit self nixpkgs pkgs; }
// import ./honomitv.nix { inherit pkgs; }
