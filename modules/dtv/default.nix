{ ... }:
{
  imports = [
    ../casproxyserver.nix
    ../hirakud.nix
    ../epgstation.nix
    ./card.nix
    ./services.nix
    ./tuners.nix
  ];
}
