{ myvars, ... }: {

  imports = [
    ../base/home.nix
    ../base/tui

    ./base
  ];
}
