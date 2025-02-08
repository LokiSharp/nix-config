{
  lib,
  mylib,
  myvars,
  pkgs,
  disko,
  ...
}:
let
  hostName = "OVH-CA-EAST-BHS";
in
{
  imports =
    [
      ./hardware-configuration.nix
      disko.nixosModules.default
      ./disko-fs.nix
      ../vps/impermanence.nix
      ./dn42.nix
    ]
    ++ map mylib.relativeToRoot [
      "modules/nixos/server/dn42.nix"
      "modules/nixos/server/bird"
      "modules/nixos/server/bind.nix"
      "modules/nixos/server/zerotierone-controller"
    ];

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "eno1";
    address = [
      "192.99.39.2/24"
      "2607:5300:60:6002::1/128"
    ];
    routes = [
      { Gateway = "192.99.39.254"; }
      {
        Gateway = "2607:5300:0060:60ff:00ff:00ff:00ff:00ff";
        GatewayOnLink = true;
      }
    ];
    linkConfig.RequiredForOnline = "routable";
  };

  networking = {
    inherit hostName;
    useDHCP = false;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
