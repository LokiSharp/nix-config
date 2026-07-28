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
    chimon = {
      remoteASN = 4242423868;
      tunnel = {
        type = "wireguard";
        localPort = 23868;
        remoteAddress = "tyo.dn42.cio.bz";
        remotePort = 23888;
        wireguardPubkey = "Bh8/7a6H2u3VOxsA8o81FYpKUgXRJYajFQjE+PwuXlE=";
      };
      addressing = {
        peerIPv4 = "172.21.65.161";
        peerIPv6 = "fdc4:c9b0:e83e:392::1";
      };
    };
  };
}
