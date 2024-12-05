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
  name = "k3s-prod-1-master-1";
  hostName = "K3S-Prod-1-Master-1";
  tags = [ name hostName ];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/server/server.nix"
        "modules/nixos/server/proxmox-hardware-configuration.nix"
        # host specific
        "hosts/k8s/${name}"
      ])
      ++ [
        {
          modules.secrets.server.kubernetes.enable = true;
          modules.secrets.impermanence.enable = true;
        }
      ];
    home-modules = map mylib.relativeToRoot [
      "home/linux/core.nix"
    ];
  };

  systemArgs = modules // args;
in
{
  nixosConfigurations.${hostName} = mylib.nixosSystem systemArgs;

  colmena.${hostName} =
    mylib.colmenaSystem (systemArgs // { inherit tags ssh-user; });

  packages.${hostName} = inputs.self.nixosConfigurations.${hostName}.config.formats.iso;
}