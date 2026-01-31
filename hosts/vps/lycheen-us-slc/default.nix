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
  ];

  disko.devices.disk.main.device = lib.mkForce "/dev/sda";

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
