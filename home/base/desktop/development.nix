{ pkgs, pkgs-unstable, ... }: {
  home.packages = with pkgs; [
    pkgs-unstable.devbox
  ];
}
