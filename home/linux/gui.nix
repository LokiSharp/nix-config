{ myvars, ... }: {
  imports = [
    ../base/core
    ../base/tui
    ../base/gui
    ../base/home.nix

    ./base
    ./tui
    ./gui
  ];
}
