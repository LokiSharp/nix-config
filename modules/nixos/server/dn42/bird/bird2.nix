{ pkgs, lib, mylib, config, ... }:
let
  hostsBase = mylib.relativeToRoot "hosts/vps";
  configLib = import (mylib.relativeToRoot "lib") { inherit config pkgs lib hostsBase; };
in
{
  services.bird2 = {
    enable = true;
    checkConfig = false;
    config = "
################################################
#               Variable header                #
################################################

define OWNAS = 4242423888;
define OWNIP = ${configLib.this.dn42.IPv4};
define OWNIPv6 = ${configLib.this.dn42.IPv6};
define OWNNET = 172.20.190.0/26;
define OWNNETv6 = fd6a:11d4:cacb::/48;
define OWNNETSET = [172.20.190.0/26+];
define OWNNETSETv6 = [fd6a:11d4:cacb::/48+];
" + builtins.readFile ./bird.conf + lib.concatStrings (lib.attrValues (builtins.mapAttrs
      (n: v: "
${if v.addressing.peerIPv4 != null then 
"protocol bgp ${v.peering.network}_${n}_v4 from dnpeers {
  neighbor ${v.addressing.peerIPv4} as ${toString v.remoteASN};
  direct;
  ipv6 {
    import none;
    export none;
  };
};" else ""}
${if v.addressing.peerIPv6 != null then 
"protocol bgp ${v.peering.network}_${n}_v6 from dnpeers {
  neighbor ${v.addressing.peerIPv6} as ${toString v.remoteASN};
  direct;
  ipv4 {
    import none;
    export none;
  };
};" else ""}
${if v.addressing.peerIPv6LinkLocal != null then 
"protocol bgp ${v.peering.network}_${n}_v6 from dnpeers {
  neighbor ${v.addressing.peerIPv6LinkLocal} % '${v.peering.network}-${n}' as ${toString v.remoteASN};
  direct;
  ipv4 {
    import none;
    export none;
  };
};" else ""}
")
      config.services.dn42));
  };
}
