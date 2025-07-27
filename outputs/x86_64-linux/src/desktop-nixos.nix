{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
let
  hostName = "DESKTOP-NixOS";
  hostNameLower = lib.toLower hostName;
  tags = [
    hostName
    hostNameLower
    "desktop"
  ];
  ssh-user = "root";

  base-modules = {
    nixos-modules = map mylib.relativeToRoot [
      # common
      "modules/nixos/desktop.nix"
      # host specific
      "hosts/${hostNameLower}"
    ];
    home-modules = map mylib.relativeToRoot [
      # common
      "home/linux/gui.nix"
      # host specific
      "hosts/${hostNameLower}/home.nix"
    ];
  };

  modules = {
    nixos-modules = [
      {
        modules.desktop.fonts.enable = true;
        modules.desktop.wayland.enable = true;
      }
    ] ++ base-modules.nixos-modules;
    home-modules = [
      { modules.desktop.hyprland.enable = true; }
    ] ++ base-modules.home-modules;
  };

  systemArgs = modules // args;
in
{
  nixosConfigurations = {
    "${hostName}" = mylib.nixosSystem systemArgs;
  };

  colmena.${hostName} = mylib.colmenaSystem (systemArgs // { inherit tags ssh-user; });

  # generate iso image for hosts with desktop environment
  packages = {
    "${hostName}" = inputs.self.nixosConfigurations."${hostName}".config.formats.iso;
  };
}
