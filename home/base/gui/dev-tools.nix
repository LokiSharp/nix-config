{ pkgs, pkgs-unstable, ... }: {
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

  programs.vscode = {
    package = pkgs.vscode;
    enable = true;
    extensions = (with pkgs;
      with vscode-extensions; [
        rust-lang.rust-analyzer
        ms-vscode.cpptools
        ms-vscode-remote.remote-ssh
      ]);
  };
}
