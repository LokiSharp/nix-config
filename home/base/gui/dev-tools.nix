{ pkgs, pkgs-unstable, ... }: {
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
