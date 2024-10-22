{ pkgs
, ...
}: {
  xdg.configFile."foot/foot.ini".text =
    ''
      [main]
      dpi-aware=yes
      font=JetBrainsMono Nerd Font:size=13
      shell=${pkgs.bash}/bin/bash --login -c 'nu --login --interactive'
      term=foot
      initial-window-size-pixels=3840x2160
      initial-window-mode=windowed
      pad=0x0                             # optionally append 'center'
      resize-delay-ms=10

      [mouse]
      hide-when-typing=yes
    '';

  home.packages = [
    pkgs.firefox-wayland
  ];

  programs = {
    # a wayland only terminal emulator
    foot = {
      enable = true;
      # foot can also be run in a server mode. In this mode, one process hosts multiple windows.
      # All Wayland communication, VT parsing and rendering is done in the server process.
      # New windows are opened by running footclient, which remains running until the terminal window is closed.
      #
      # Advantages to run foot in server mode including reduced memory footprint and startup time.
      # The downside is a performance penalty. If one window is very busy with, for example, producing output,
      # then other windows will suffer. Also, should the server process crash, all windows will be gone.
      server.enable = true;
    };
  };
}
