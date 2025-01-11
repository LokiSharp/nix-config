{ pkgs, lib, mylib, config, ... }:
let
  configLib = mylib.withConfig config;
in
rec {
  this = configLib.this;
  DN42_AS = "4242423888";
  SLK_NET_ANYCAST_DNS_IPv4 = "172.20.190.53";
  SLK_NET_ANYCAST_DNS_IPv6 = "fd6a:11d4:cacb::53";
}
