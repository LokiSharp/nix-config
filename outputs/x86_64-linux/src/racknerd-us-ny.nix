{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs
, lib
, mylib
, myvars
, system
, genSpecialArgs
, ...
} @ args:
let
  name = "racknerd-us-ny";
  hostName = "RackNerd-US-NY";
  targetHost = "racknerd-us-ny.slk.moe";
  tags = [ name hostName "vps" ];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/server.nix"
        "modules/nixos/hardware-configuration/vps-hardware-configuration.nix"
        # host specific
        "hosts/vps/${name}"
      ])
      ++ [ ];
    home-modules = map mylib.relativeToRoot [
      "home/linux/core.nix"
    ];
  };

  systemArgs = modules // args;
in
{
  nixosConfigurations.${hostName} = mylib.nixosSystem systemArgs;

  colmena.${hostName} =
    mylib.colmenaSystem (systemArgs // { inherit tags targetHost ssh-user; });

  packages.${hostName} = inputs.self.nixosConfigurations.${hostName}.config.formats.iso;
}
