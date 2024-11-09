{ pkgs, pkgs-unstable, vscode-server, ... }: {
  home.packages = with pkgs; [
    colmena # nixos's remote deployment tool

    sqlite
  ];

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;

      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
    };
  };
}
