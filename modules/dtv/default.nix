{ ... }:
{
  imports = [
    ../casproxyserver.nix
    ../hirakud.nix
    ../epgstation.nix
    ./bs4k.nix
    ./card.nix
    ./services.nix
    ./tuners.nix
  ];
}
