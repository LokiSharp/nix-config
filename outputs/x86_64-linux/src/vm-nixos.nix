{ inputs
, lib
, myvars
, mylib
, system
, genSpecialArgs
, ...
}:
let
  hostName = "VM-NixOS";
  hostNameLower = lib.toLower hostName;
  tags = [ hostName ] ++ mylib.hosts.${hostNameLower}.deploymentTags;
  ssh-user = "root";

  base-modules = {
    nixos-modules = map mylib.relativeToRoot [
      # common
      "secrets/nixos.nix"
      "modules/nixos/desktop.nix"
      "modules/nixos/hardware-configuration/proxmox-hardware-configuration.nix"
      # host specific
      "hosts/${hostNameLower}"
    ];
    home-modules = map mylib.relativeToRoot [
      # common
      "home/linux/gui.nix"
      "home/linux/develop"
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

  systemArgs = modules // {
    inherit
      inputs
      lib
      mylib
      myvars
      system
      genSpecialArgs
      ;
  };
in
{
  nixosConfigurations = {
    "${hostName}" = mylib.nixosSystem systemArgs;
  };

  colmena.${hostName} = mylib.colmenaSystem (systemArgs // { inherit tags ssh-user; });
}
