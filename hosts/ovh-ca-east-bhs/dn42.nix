{ config, inputs, ... }:
{
  services.dn42 = {
    lantian = {
      remoteASN = 4242422547;
      tunnel = {
        type = "wireguard";
        localPort = 22547;
        remoteAddress = "virmach-ny1g.lantian.pub";
        remotePort = 23888;
        wireguardPubkey = "a+zL2tDWjwxBXd2bho2OjR/BEmRe2tJF9DHFmZIE+Rk=";
      };
      addressing = {
        peerIPv4 = "172.22.76.190";
        peerIPv6LinkLocal = "fe80::2547";
      };
    };
  };

  services.dn42 = {
    sunnet = {
      remoteASN = 4242423088;
      tunnel = {
        type = "wireguard";
        localPort = 23088;
        remoteAddress = "sjc1-us.dn42.6700.cc";
        remotePort = 23888;
        wireguardPubkey = "G/ggwlVSy5jKWFlJM01hxcWnL8VDXsD5EXZ/S47SmhM=";
      };
      addressing = {
        peerIPv4 = "172.21.100.191";
        peerIPv6LinkLocal = "fe80::3088:191";
      };
    };
  };

  services.dn42 = {
    kioubit = {
      remoteASN = 4242423914;
      tunnel = {
        type = "wireguard";
        localPort = 23914;
        remoteAddress = "us2.g-load.eu";
        remotePort = 23888;
        wireguardPubkey = "6Cylr9h1xFduAO+5nyXhFI1XJ0+Sw9jCpCDvcqErF1s=";
      };
      addressing = {
        peerIPv4 = "172.20.53.98";
        peerIPv6LinkLocal = "fe80::ade0";
      };
    };
  };
}
