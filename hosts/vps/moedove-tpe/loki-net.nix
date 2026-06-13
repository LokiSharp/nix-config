{ config, ... }:
{
  services.loki-net = {
    chief-rs1 = {
      remoteASN = 10133;
      peerBgpPasswordConf = config.sops.templates."chief-rs-password.conf".path;
      addressing = {
        peerIPv4 = "203.163.222.253";
        peerIPv6 = "2406:d400:1:133:203:163:222:253";
      };
    };

    chief-rs2 = {
      remoteASN = 10133;
      peerBgpPasswordConf = config.sops.templates."chief-rs-password.conf".path;
      addressing = {
        peerIPv4 = "203.163.222.254";
        peerIPv6 = "2406:d400:1:133:203:163:222:254";
      };
    };
  };
}
