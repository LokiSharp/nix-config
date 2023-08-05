{ pkgs, ... }: {
  programs.tmux = {
    enable = true;
    shell = "${pkgs.nushell}/bin/nu";
  };
}
