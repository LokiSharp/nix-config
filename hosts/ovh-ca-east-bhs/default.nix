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

  networking = {
    inherit hostName;
    useDHCP = false;
    nameservers = [ "8.8.8.8" ];
    interfaces."eno1" = {
      ipv4.addresses = [
        {
          address = "192.99.39.2";
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = "2607:5300:60:6002::1";
          prefixLength = 128;
        }
      ];
    };
    defaultGateway = {
      address = "192.99.39.254";
      interface = "eno1";
    };
    defaultGateway6 = {
      address = "2607:5300:0060:60ff:00ff:00ff:00ff:00ff";
      interface = "eno1";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
