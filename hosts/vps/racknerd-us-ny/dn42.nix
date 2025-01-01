{ config, inputs, ... }:
{
  services.dn42 = {
    sunnet = {
      remoteASN = 4242423088;
      tunnel = {
        type = "wireguard";
        localPort = 23088;
        remoteAddress = "lax1-us.dn42.6700.cc";
        remotePort = 23888;
        wireguardPubkey = "QSAeFPotqFpF6fFe3CMrMjrpS5AL54AxWY2w1+Ot2Bo=";
      };
      addressing = {
        peerIPv4 = "172.21.100.193";
        peerIPv6LinkLocal = "fe80::3088:193";
      };
    };
  };
}
