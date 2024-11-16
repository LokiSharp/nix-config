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
  name = "server-nixos";
  hostName = "Server-NixOS";
  tags = [ name ];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/server/server.nix"
        "modules/nixos/server/proxmox-hardware-configuration.nix"
        # host specific
        "hosts/${name}"
      ])
      ++ [
        { modules.secrets.server.webserver.enable = true; }
      ];
    home-modules = map mylib.relativeToRoot [
      "home/linux/tui.nix"
    ];
  };

  systemArgs = modules // args;
in
{
  nixosConfigurations.${hostName} = mylib.nixosSystem systemArgs;

  colmena.${hostName} =
    mylib.colmenaSystem (systemArgs // { inherit tags ssh-user; });

  packages.${hostName} = inputs.self.nixosConfigurations.${hostName}.config.formats.kubevirt;
}
