{
  lib,
  mylib,
  myvars,
  pkgs,
  disko,
  ...
}:
let
  hostName = "Server-NixOS";
in
{
  imports = (mylib.scanPaths ./services) ++ [
    disko.nixosModules.default
    ./disko-fs.nix
    ./disko-fs-data.nix
    ./impermanence.nix
  ];

  systemd.network.enable = true;
  networking = {
    inherit hostName;
    useNetworkd = true;
    useDHCP = true;
    inherit (myvars.networking) nameservers;
  };

  services.resolved = {
    enable = true;
    domains = [ "lan" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
