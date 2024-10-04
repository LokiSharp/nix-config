{ myvars, ... }: {

  imports = [
    ../base/server
    ./base
  ];

  home = {
    inherit (myvars) username;
    stateVersion = "24.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
