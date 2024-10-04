{ myvars, ... }: {
  imports = [
    ../base/desktop
    ./base
    ./desktop
  ];

  home = {
    inherit (myvars) username;
    stateVersion = "24.05";
  };

  programs.home-manager.enable = true;
}
