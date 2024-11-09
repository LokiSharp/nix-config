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
  name = "vm-kubevirt-node-1";
  hostName = "VM-Kubevirt-Node-1";
  tags = [ name ];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "modules/nixos/server/server.nix"
        # host specific
        "hosts/k8s/${name}"
      ])
      ++ [
        # {modules.secrets.server.kubernetes.enable = true;}
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
