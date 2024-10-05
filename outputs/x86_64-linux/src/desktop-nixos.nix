{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs
, lib
, myvars
, mylib
, system
, genSpecialArgs
, ...
} @ args:
let
  name = "desktop-nixos";
  hostName = "DESKTOP-NixOS";
  base-modules = {
    nixos-modules = map mylib.relativeToRoot [
      # common
      "modules/nixos/desktop.nix"
      # host specific
      "hosts/${name}"
    ];
    home-modules = map mylib.relativeToRoot [
      # common
      "home/linux/gui.nix"
      # host specific
      "hosts/${name}/home.nix"
    ];
  };

  modules = {
    nixos-modules =
      [
        { }
      ]
      ++ base-modules.nixos-modules;
    home-modules =
      [
        { }
      ]
      ++ base-modules.home-modules;
  };

  systemArgs = modules // args;
in
{
  nixosConfigurations = {
    "${hostName}" = mylib.nixosSystem systemArgs;
  };

  # generate iso image for hosts with desktop environment
  packages = {
    "${hostName}" = inputs.self.nixosConfigurations."${name}".config.formats.iso;
  };
}
