{
  lib,
  mylib,
  myvars,
  pkgs,
  disko,
  ...
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
    "modules/nixos/server/bird"
    "modules/nixos/server/bind.nix"
    "modules/nixos/server/proxy.nix"
  ];

  disko.devices.disk.main.device = lib.mkForce "/dev/sda";

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "en*";
    address = [
      "23.175.25.121/24"
      "2a13:a5c3:3130::121/128"
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
  networking = {
    inherit hostName;
    useNetworkd = true;
  };

  modules.server.proxy = {
    enable = true;
  };

  system.stateVersion = "24.11"; # Did you read the comment?
}
