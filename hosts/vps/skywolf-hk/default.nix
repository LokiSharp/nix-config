{
  lib,
  mylib,
  myvars,
  pkgs,
  disko,
  ...
}:
let
  hostName = "SkyWolf-HK";
in
{
  imports = [
    disko.nixosModules.default
    ../disko-config/vps-disko-fs.nix
    ../impermanence.nix
    ./dn42.nix
    ./loki-net.nix
  ]
  ++ map mylib.relativeToRoot [
    "modules/nixos/server/dn42.nix"
    "modules/nixos/server/loki-net.nix"
    "modules/nixos/server/bird"
    "modules/nixos/server/bind.nix"
    "modules/nixos/server/zerotierone-controller"
    "modules/nixos/server/proxy.nix"
  ];

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "en*";
    address = [
      "103.213.4.88/24"
      "2401:5a0:1000:59::a/64"
    ];
    routes = [
      { Gateway = "103.213.4.1"; }
      {
        Gateway = "2401:5a0:1000::1";
        GatewayOnLink = true;
      }
    ];
    linkConfig.RequiredForOnline = "routable";
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
