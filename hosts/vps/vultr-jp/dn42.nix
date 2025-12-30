{ config, inputs, ... }:
{
  services.dn42 = {
    sunnet = {
      remoteASN = 4242423088;
      tunnel = {
        type = "wireguard";
        localPort = 23088;
        remoteAddress = "tyo1-jp.dn42.6700.cc";
        remotePort = 23888;
        wireguardPubkey = "b3gUz8an2+wSCvXAwuxGR7AnxKDUqqQMd1+LASo93R0=";
      };
      addressing = {
        peerIPv4 = "172.21.100.190";
        peerIPv6LinkLocal = "fe80::3088:190";
      };
    };
  };

  services.dn42 = {
    kioubit = {
      remoteASN = 4242423914;
      tunnel = {
        type = "wireguard";
        localPort = 23914;
        remoteAddress = "sg1.g-load.eu";
        remotePort = 23888;
        wireguardPubkey = "jLVjxykR8WSveNIJV1Of6utpp0fwANu3jgWmLnkFkWw=";
      };
      addressing = {
        peerIPv4 = "172.20.53.106";
        peerIPv6LinkLocal = "fe80::ade0";
      };
    };
  };
}
