{ config, inputs, ... }:
{
  services.loki-net = {
    skywolf_hk = {
      remoteASN = 7720;
      addressing = {
        peerIPv4 = "100.100.0.0";
        peerIPv6 = "fd00:7720::1";
        peerIPv6Gateway = "fe80::220:8fff:feea:dbf5%ens3";
      };
    };
  };
}
