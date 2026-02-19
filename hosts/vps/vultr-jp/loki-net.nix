{ config, inputs, ... }:
{
  services.loki-net = {
    skywolf_hk = {
      remoteASN = 64515;
      peerBgpPasswordConf = config.sops.templates."bird-bgp-password.conf".path;
      addressing = {
        peerIPv4 = "169.254.169.254";
        peerIPv6 = "2001:19f0:ffff::1";
        peerIPv6Gateway = "fe80::5400:5ff:fe3a:2641%ens3";
      };
    };
  };
}
