{ pkgs, pkgs-unstable, vscode-server, ... }: {
  home.packages = with pkgs; [
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
