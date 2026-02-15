{
  mylib,
  config,
  lib,
  ...
}:
let
  configLib = mylib.withConfig config;
in
{
  networking.nftables = {
    enable = configLib.this.hasTag configLib.tags.firewall;
    ruleset = ''
      # Check out https://wiki.nftables.org/ for better documentation.
      # Table for both IPv4 and IPv6.
      table inet filter {
        # Block all incoming connections traffic except SSH and "ping".
        chain input {
          type filter hook input priority 0;

          # accept any localhost traffic
          iifname lo accept
          iifname dummy0 accept

          ${
            if configLib.this.hasTag configLib.tags.zerotier then
              ''
                # accept ZeroTier traffic
                iifname "zt-slk0" accept
              ''
            else
              ""
          }

          ${
            if configLib.this.hasTag configLib.tags.dn42 then
              ''
                # accept DN42 traffic
                iifname "dn42-*" accept
              ''
            else
              ""
          }

          # accept traffic originated from us
          ct state {established, related} accept

          # ICMP
          # routers may also want: mld-listener-query, nd-router-solicit
          ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
          ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept

          # allow "ping"
          ip6 nexthdr icmpv6 icmpv6 type echo-request accept
          ip protocol icmp icmp type echo-request accept

          # accept SSH connections (required for a server)
          tcp dport 22 accept

          ${
            if
              configLib.this.hasTag configLib.tags.loki-net
              && config.services ? loki-net
              && config.services.loki-net != { }
            then
              let
                peers = lib.attrValues config.services.loki-net;
                mkRule =
                  peer:
                  (lib.optionalString (peer.addressing.peerIPv4 != null && peer.addressing.peerIPv4 != "") ''
                    ip saddr ${peer.addressing.peerIPv4} tcp dport 179 accept
                  '')
                  + (lib.optionalString (peer.addressing.peerIPv6 != null && peer.addressing.peerIPv6 != "") ''
                    ip6 saddr ${peer.addressing.peerIPv6} tcp dport 179 accept
                  '');
              in
              ''
                # accept BIRD 2 BGP traffic from specific peers
                ${lib.concatMapStrings mkRule peers}
              ''
            else
              ""
          }

          # Accept ports defined in standard firewall options
          ${lib.optionalString (config.networking.firewall.allowedTCPPorts != [ ]) ''
            tcp dport { ${lib.concatStringsSep ", " (map toString config.networking.firewall.allowedTCPPorts)} } accept
          ''}
          ${lib.optionalString (config.networking.firewall.allowedUDPPorts != [ ]) ''
            udp dport { ${lib.concatStringsSep ", " (map toString config.networking.firewall.allowedUDPPorts)} } accept
          ''}

          # count and drop any other traffic
          counter drop
        }

        # Allow all outgoing connections.
        chain output {
          type filter hook output priority 0;
          accept
        }

        chain forward {
          type filter hook forward priority 0;
          accept
        }
      }    
    '';
  };
}
