{ lib
, mylib
, myvars
, pkgs
, disko
, ...
}:
let
  hostName = "RackNerd-US-NY";
in
{
  imports = [
    disko.nixosModules.default
    ../disko-config/vps-disko-fs.nix
    ../impermanence.nix
    ./dn42.nix
  ] ++ map mylib.relativeToRoot [
    "modules/nixos/server/dn42"
  ];

  systemd.network.enable = true;
  networking = {
    inherit hostName;
    useNetworkd = true;
    useDHCP = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
