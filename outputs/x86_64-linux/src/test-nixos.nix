{ inputs
, lib
, myvars
, mylib
, system
, genSpecialArgs
, ...
}:
let
  hostName = "Test-NixOS";
  hostNameLower = lib.toLower hostName;
  tags = [ hostName ] ++ mylib.hosts.${hostNameLower}.deploymentTags;
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
        {
          modules.secrets = {
            server = {
              dn42.enable = true;
              loki-net.enable = true;
            };
            impermanence.enable = true;
          };
        }
      ];
    home-modules = map mylib.relativeToRoot [
      "home/linux/core.nix"
    ];
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
  nixosConfigurations.${hostName} = mylib.nixosSystem systemArgs;

  colmena.${hostName} = mylib.colmenaSystem (systemArgs // { inherit tags ssh-user; });
}
