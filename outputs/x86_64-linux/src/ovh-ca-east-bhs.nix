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
  hostName = "OVH-CA-EAST-BHS";
  hostNameLower = lib.toLower hostName;
  tags = [
    hostName
    hostNameLower
    "vps"
    "dn42"
    "loki-net"
  ];
  targetHost = "ovh-ca-east-bhs.slk.moe";
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/server.nix"
        # host specific
        "hosts/${hostNameLower}"
      ])
      ++ [
        {
          modules.secrets.server.dn42.enable = true;
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

  colmena.${hostName} = mylib.colmenaSystem (systemArgs // { inherit tags targetHost ssh-user; });

  packages.${hostName} = inputs.self.nixosConfigurations.${hostName}.config.formats.iso;
}
