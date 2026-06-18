{ config, ... }:
{
  services.loki-net = {
    chief-rs = {
      remoteASN = 17408;
      peerBgpPasswordConf = config.sops.templates."chief-rs-password.conf".path;
      addressing = {
        peerIPv4 = "113.21.83.177";
        peerIPv6 = "2405:7e00:1:7408:113:21:83:175";
      };
    };

    tpix-rs1 = {
      remoteASN = 10133;
      peerBgpPasswordConf = config.sops.templates."tpix-rs-password.conf".path;
      addressing = {
        peerIPv4 = "203.163.222.253";
        peerIPv6 = "2406:d400:1:133:203:163:222:253";
      };
    };

    tpix-rs2 = {
      remoteASN = 10133;
      peerBgpPasswordConf = config.sops.templates."tpix-rs-password.conf".path;
      addressing = {
        peerIPv4 = "203.163.222.254";
        peerIPv6 = "2406:d400:1:133:203:163:222:254";
      };
    };

    he = {
      remoteASN = 6939;
      addressing = {
        peerIPv4 = "203.163.222.43";
        peerIPv6 = "2406:d400:1:133:203:163:222:43";
      };
    };
  };
}
