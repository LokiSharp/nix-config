{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.desktop.hyprland;
in
{
  options.modules.desktop.hyprland = {
    nvidia = mkEnableOption "whether nvidia GPU is used";
  };

  config = mkIf (cfg.enable && cfg.nvidia) {
    wayland.windowManager.hyprland.settings.env = [
      # for hyprland with nvidia gpu, ref https://wiki.hyprland.org/Nvidia/
      {
        _args = [
          "LIBVA_DRIVER_NAME"
          "nvidia"
        ];
      }
      {
        _args = [
          "XDG_SESSION_TYPE"
          "wayland"
        ];
      }
      {
        _args = [
          "GBM_BACKEND"
          "nvidia-drm"
        ];
      }
      {
        _args = [
          "__GLX_VENDOR_LIBRARY_NAME"
          "nvidia"
        ];
      }
      # fix https://github.com/hyprwm/Hyprland/issues/1520
      {
        _args = [
          "WLR_NO_HARDWARE_CURSORS"
          "1"
        ];
      }
    ];
  };
}
