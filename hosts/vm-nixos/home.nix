{
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
