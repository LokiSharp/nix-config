{ pkgs, ... }: {
  home.packages = with pkgs; [
    bat
    htop
    iotop
    iftop
  ];
}
