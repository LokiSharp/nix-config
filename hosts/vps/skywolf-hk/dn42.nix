{ config, inputs, ... }:
{
  services.dn42 = {
    sunnet = {
      remoteASN = 4242423088;
      tunnel = {
        type = "wireguard";
        localPort = 23088;
        remoteAddress = "hk1-hk.dn42.6700.cc";
        remotePort = 23888;
        wireguardPubkey = "rBTH+JyZB0X/DkwHByrCjCojxBKr/kEOm1dTAFGHR1w=";
      };
      addressing = {
        peerIPv4 = "172.21.100.192";
        peerIPv6LinkLocal = "fe80::3088:192";
      };
    };
  };


  services.dn42 = {
    kioubit = {
      remoteASN = 4242423914;
      tunnel = {
        type = "wireguard";
        localPort = 23914;
        remoteAddress = "hk1.g-load.eu";
        remotePort = 23888;
        wireguardPubkey = "sLbzTRr2gfLFb24NPzDOpy8j09Y6zI+a7NkeVMdVSR8=";
      };
      addressing = {
        peerIPv4 = "172.20.53.105";
        peerIPv6LinkLocal = "fe80::ade0";
      };
    };
  };
}
