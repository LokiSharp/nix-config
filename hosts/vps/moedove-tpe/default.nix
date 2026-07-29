{ lib
, mylib
, disko
, ...
}:
let
  hostName = "MoeDove-TPE";
in
{
  imports = [
    disko.nixosModules.default
    ../disko-config/vps-disko-fs.nix
    ../impermanence.nix
  ]
  ++ map mylib.relativeToRoot [
    "modules/nixos/server/dn42.nix"
    "modules/nixos/server/loki-net.nix"
    "modules/nixos/server/bird"
    "modules/nixos/server/bind.nix"
    "modules/nixos/server/proxy.nix"
  ];

  modules.base.hardening."stage-2".enforceProfiles = [
    "named"
    "bird"
    "caddy"
    "sing-box"
    "zerotierone"
    "tailscale"
  ];

  disko.devices.disk.main.device = lib.mkForce "/dev/sda";

  systemd.network = {
    enable = true;
    links = {
      "10-wan-alias" = {
        matchConfig.OriginalName = "ens18";
        linkConfig.AlternativeName = "wan";
      };
    };
    networks = {
      "20-wan" = {
        matchConfig.Name = "ens18";
        address = [
          "23.175.25.121/24"
          "2a13:a5c3:3130::121/64"
        ];
        routes = [
          { Gateway = "23.175.25.1"; }
          {
            Gateway = "2a13:a5c3:3130::1";
            GatewayOnLink = true;
          }
        ];
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  networking = {
    inherit hostName;
    useNetworkd = true;
  };

  modules.server.proxy = {
    enable = true;
  };

  system.stateVersion = "24.11"; # Did you read the comment?
}
