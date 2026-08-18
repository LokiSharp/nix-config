{ config, lib, ... }:
{
  networking.nftables = lib.mkIf (config.virtualisation.podman.enable or false) {
    extraForwardRules = ''
      iifname "podman*" accept
      oifname "podman*" ct status dnat accept
    '';
  };
}
