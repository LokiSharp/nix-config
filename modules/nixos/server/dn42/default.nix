{ mylib, ... }: {
  imports = [
    ./dn42.nix
    ./bird
    ./bind.nix
  ];
}
