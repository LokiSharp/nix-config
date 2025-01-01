{ pkgs, lib, config, ... }: {
  services.bird2 = {
    enable = true;
    checkConfig = false;
    config = builtins.readFile ./bird.conf + lib.concatStrings (lib.attrValues (builtins.mapAttrs
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
