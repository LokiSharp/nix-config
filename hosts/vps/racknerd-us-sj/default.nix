{
  lib,
  mylib,
  myvars,
  pkgs,
  disko,
  ...
}:
let
  hostName = "RackNerd-US-SJ";
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

  systemd.network.enable = true;
  systemd.network.networks."20-wan" = {
    matchConfig.Name = "ens*";
    networkConfig.DHCP = "yes";
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
