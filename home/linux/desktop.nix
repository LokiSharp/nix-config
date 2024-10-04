{ username, ... }: {
  imports = [
    ../base/desktop
    ./base
    ./desktop
  ];

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.05";
  };

  programs.home-manager.enable = true;
}
