{ mylib
, disko
, ...
}:
let
  hostName = "Vultr-JP";
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

  systemd.network = {
    enable = true;
    links."10-wan-alias" = {
      matchConfig.OriginalName = "ens3";
      linkConfig.AlternativeName = "wan";
    };
    networks."20-wan" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "yes";
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
