{
  pkgs,
  lib,
  ...
}:
let
  package = pkgs.hyprland;
in
{
  wayland.windowManager.hyprland = {
    inherit package;
    enable = true;
    configType = "lua";
    settings = {
      env = [
        {
          _args = [
            "NIXOS_OZONE_WL"
            "1"
          ];
        } # Chromium and Electron on Wayland
        {
          _args = [
            "MOZ_ENABLE_WAYLAND"
            "1"
          ];
        }
        {
          _args = [
            "MOZ_WEBRENDER"
            "1"
          ];
        }
        {
          _args = [
            "_JAVA_AWT_WM_NONREPARENTING"
            "1"
          ];
        }
        {
          _args = [
            "QT_WAYLAND_DISABLE_WINDOWDECORATION"
            "1"
          ];
        }
        {
          _args = [
            "QT_QPA_PLATFORM"
            "wayland"
          ];
        }
        {
          _args = [
            "SDL_VIDEODRIVER"
            "wayland"
          ];
        }
        {
          _args = [
            "GDK_BACKEND"
            "wayland"
          ];
        }
        {
          _args = [
            "SSH_AUTH_SOCK"
            (lib.generators.mkLuaInline ''os.getenv("XDG_RUNTIME_DIR") .. "/ssh-agent"'')
          ];
        }
      ];
    };
    extraConfig = builtins.readFile ../conf/hyprland.lua;
    # gammastep/wallpaper-switcher need this to be enabled.
    systemd = {
      enable = true;
      variables = [ "--all" ];
    };
  };

  # NOTE: this executable is used by greetd to start a wayland session when system boot up
  # with such a vendor-no-locking script, we can switch to another wayland compositor without modifying greetd's config in NixOS module
  home.file.".wayland-session" = {
    source = "${package}/bin/start-hyprland";
    executable = true;
  };

  # hyprland configs, based on https://github.com/notwidow/hyprland
  xdg.configFile = {
    "hypr/mako" = {
      source = ../conf/mako;
      recursive = true;
    };
    "hypr/scripts" = {
      source = ../conf/scripts;
      recursive = true;
    };
    "hypr/waybar" = {
      source = ../conf/waybar;
      recursive = true;
    };
    "hypr/wlogout" = {
      source = ../conf/wlogout;
      recursive = true;
    };

    # music player - mpd
    "mpd" = {
      source = ../conf/mpd;
      recursive = true;
    };
  };
}
