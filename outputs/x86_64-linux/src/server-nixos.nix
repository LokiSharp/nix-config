{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}@args:
let
  hostName = "Server-NixOS";
  hostNameLower = lib.toLower hostName;
  tags = [
    hostName
    hostNameLower
    "homelab-network"
  ];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/server.nix"
        "modules/nixos/hardware-configuration/proxmox-hardware-configuration.nix"
        # host specific
        "hosts/${hostNameLower}"
      ])
      ++ [
        { modules.secrets.server.application.enable = true; }
        { modules.secrets.server.operation.enable = true; }
        { modules.secrets.server.webserver.enable = true; }
        { modules.secrets.server.storage.enable = true; }
        { modules.secrets.impermanence.enable = true; }
      ];
    home-modules = map mylib.relativeToRoot [
      "home/linux/tui.nix"
    ];
  };

  systemArgs = modules // args;
in
{
  nixosConfigurations.${hostName} = mylib.nixosSystem systemArgs;

  colmena.${hostName} = mylib.colmenaSystem (systemArgs // { inherit tags ssh-user; });
}
