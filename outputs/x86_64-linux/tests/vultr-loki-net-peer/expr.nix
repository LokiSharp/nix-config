{ lib, outputs, ... }:

let
  config = outputs.nixosConfigurations.Vultr-JP.config;
  peer = config.services.loki-net.vultr.addressing;
in
{
  ipv6PeerAddress = peer.peerIPv6 == "2001:19f0:ffff::1";
  ipv6PeerGateway = peer.peerIPv6Gateway == "fe80::fc00:5ff:fe3a:2641%ens3";
  birdStaticRoute = lib.hasInfix
    "route 2001:19f0:ffff::1/128 via fe80::fc00:5ff:fe3a:2641%ens3;"
    config.services.bird.config;
}
