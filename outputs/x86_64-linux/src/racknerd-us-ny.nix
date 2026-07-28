{ inputs
, lib
, mylib
, myvars
, system
, genSpecialArgs
, ...
}:
let
  hostName = "RackNerd-US-NY";
  hostNameLower = lib.toLower hostName;
  tags = [ hostName ] ++ mylib.hosts.${hostNameLower}.deploymentTags;
  targetHost = "racknerd-us-ny.slk.moe";
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/server.nix"
        "modules/nixos/hardware-configuration/vps-hardware-configuration.nix"
        # host specific
        "hosts/vps/${hostNameLower}"
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

  colmena.${hostName} = mylib.colmenaSystem (systemArgs // { inherit tags targetHost ssh-user; });
}
