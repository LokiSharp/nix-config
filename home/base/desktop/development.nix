{ pkgs, pkgs-unstable, ... }: {
  home.packages = with pkgs; [
    pkgs-unstable.devbox

    mycli
    pgcli
    mongosh
    sqlite

    mitmproxy
    protobuf

    pkgs-unstable.jetbrains-toolbox
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
    package = pkgs-unstable.vscode;
    enable = true;
    extensions = (with pkgs-unstable;
      with vscode-extensions; [
        matklad.rust-analyzer
        ms-python.python
        ms-vscode.cpptools
        #ms-vscode-remote.remote-ssh # won't work with vscodium
      ]);
  };
}
