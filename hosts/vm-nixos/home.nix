{ pkgs-unstable, ... }:
{
  # Prefer Grok's managed binary so `grok update` can provide releases newer
  # than the version currently available in nixpkgs.
  home.sessionPath = [ "$HOME/.grok/bin" ];

  home.packages = [
    pkgs-unstable.claude-code
    pkgs-unstable.codex
    pkgs-unstable.grok-build
  ];

  modules.desktop.hyprland = {
    nvidia = false;
    settings = {
      # Configure your Display resolution, offset, scale and Monitors here, use `hyprctl monitors` to get the info.
      monitor = {
        output = "Virtual-1";
        mode = "1920x1080@60";
        position = "auto";
        scale = 1;
        bitdepth = 10;
      };
    };
  };
}
