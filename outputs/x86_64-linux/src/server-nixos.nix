{ inputs
, lib
, mylib
, myvars
, system
, genSpecialArgs
, ...
}:
let
  hostName = "Server-NixOS";
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
        { modules.secrets.server.application.enable = true; }
        { modules.secrets.server.operation.enable = true; }
        { modules.secrets.server.webserver.enable = true; }
        { modules.secrets.server.storage.enable = true; }
        { modules.secrets.impermanence.enable = true; }
      ];
    home-modules = map mylib.relativeToRoot [
      "home/linux/tui.nix"
      "hosts/${hostNameLower}/home.nix"
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
