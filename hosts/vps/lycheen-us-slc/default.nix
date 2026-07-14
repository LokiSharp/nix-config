{
  lib,
  mylib,
  myvars,
  pkgs,
  disko,
  ...
}:
let
  hostName = "Lycheen-US-SLC";
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

  modules.base.hardening."stage-2".enforceProfiles = [
    "named"
    "bird"
    "sing-box"
    "zerotierone"
    "tailscale"
  ];

  disko.devices.disk.main.device = lib.mkForce "/dev/sda";

  systemd.network.enable = true;
  systemd.network.links."10-wan-alias" = {
    matchConfig.OriginalName = "ens3";
    linkConfig.AlternativeName = "wan";
  };
  systemd.network.networks."20-wan" = {
    matchConfig.Name = "en*";
    address = [
      "216.238.52.228/24"
      "2602:f92a:100:e300::a/64"
    ];
    routes = [
      { Gateway = "216.238.52.1"; }
      {
        Gateway = "2602:f92a:100::1";
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
