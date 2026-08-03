{ inputs
, lib
, mylib
, myvars
, system
, genSpecialArgs
, ...
}:
let
  hostName = "OVH-CA-EAST-BHS";
  hostNameLower = lib.toLower hostName;
  tags = [ hostName ] ++ mylib.hosts.${hostNameLower}.deploymentTags;
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
          modules = {
            secrets = {
              server = {
                dn42.enable = true;
                smtp.enable = true;
              };
              impermanence.enable = true;
            };
            monitoring.externalServer = {
              enable = true;
              recipient = "me@slk.moe";
              targets = [
                {
                  name = "Server-NixOS";
                  url = "https://git.slk.moe/api/healthz";
                  connectAddress = "198.18.0.12";
                }
                {
                  name = "VictoriaMetrics";
                  url = "https://prometheus.slk.moe/health";
                  connectAddress = "198.18.0.12";
                }
                {
                  name = "Alertmanager";
                  url = "https://alertmanager.slk.moe/-/healthy";
                  connectAddress = "198.18.0.12";
                }
              ];
            };
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

  colmena.${hostName} = mylib.colmenaSystem (systemArgs // { inherit tags targetHost ssh-user; });
}
