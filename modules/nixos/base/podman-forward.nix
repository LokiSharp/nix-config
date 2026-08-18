{ config, lib, ... }:
{
  networking.nftables = lib.mkIf (config.virtualisation.podman.enable or false) {
    # Bridge DNS goes to the host resolver (aardvark). SSH stays on
    # allowedTCPPorts and is not restricted here.
    extraInputRules = ''
      iifname "podman*" udp dport 53 accept
      iifname "podman*" tcp dport 53 accept
    '';
    extraForwardRules = ''
      iifname "podman*" accept
      oifname "podman*" ct status dnat accept
    '';
  };
}
