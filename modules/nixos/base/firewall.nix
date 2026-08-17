{ mylib
, config
, lib
, ...
}:
let
  configLib = mylib.withConfig config;
in
{
  options.networking.nftables.extraInputRules = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Extra inet filter input rules inserted before the default drop.
      An accept here is the verdict that actually opens a port; a
      separate nftables table cannot override this chain's final drop.
    '';
  };

  config = {
    networking.firewall.enable = lib.mkDefault false;

    networking.nftables = {
      enable = configLib.this.features.firewall.enable;
      # Only replace the table managed here. Flushing the complete ruleset also
      # removes dynamic NAT tables installed by Podman/Netavark.
      flushRuleset = false;
      tables.filter = {
        family = "inet";
        content = ''
          # Check out https://wiki.nftables.org/ for better documentation.
          # Block all incoming connections traffic except SSH and "ping".
          chain input {
              type filter hook input priority 0;

              # Drop routing loops between ZeroTier and Tailscale
              iifname "tailscale0" oifname "zt-slk0" drop
              iifname "zt-slk0" oifname "tailscale0" drop
              iifname "tailscale0" udp dport 9993 drop
              iifname "zt-slk0" udp dport 41641 drop

              # accept any localhost traffic
              iifname lo accept
              iifname dummy0 accept

              ${
                if configLib.this.features.zerotier.enable then
                  ''
                    # accept ZeroTier traffic
                    iifname "zt-slk0" accept
                  ''
                else
                  ""
              }

              ${
                if configLib.this.networks.dn42.enable then
                  ''
                    # accept DN42 traffic
                    iifname "dn42-*" accept
                  ''
                else
                  ""
              }

              ${
                if configLib.this.features.tailscale.enable then
                  ''
                    # accept Tailscale traffic
                    iifname "tailscale0" accept
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
              tcp dport ${builtins.toString configLib.this.sshPort} accept

              ${
                if
                  configLib.this.networks.loki-net.enable
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
                    # accept BIRD BGP traffic from specific peers
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

              ${config.networking.nftables.extraInputRules}

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

              # Drop routing loops between ZeroTier and Tailscale
              iifname "tailscale0" oifname "zt-slk0" drop
              iifname "zt-slk0" oifname "tailscale0" drop

              ct state invalid drop
              ct state { established, related } accept

              ${lib.optionalString configLib.this.features.zerotier.enable ''
                # Forward traffic to and from the trusted ZeroTier network.
                iifname "zt-slk0" accept
                oifname "zt-slk0" accept
              ''}

              ${lib.optionalString configLib.this.networks.dn42.enable ''
                # DN42 routes are carried only by explicitly configured peer tunnels.
                iifname "dn42-*" accept
                oifname "dn42-*" accept
              ''}

              ${lib.optionalString configLib.this.features.tailscale.enable ''
                # Forward traffic to and from the trusted Tailscale network.
                iifname "tailscale0" accept
                oifname "tailscale0" accept
              ''}

              ${lib.optionalString configLib.this.networks.loki-net.enable ''
                # Route only the allocated Loki-Net IPv6 aggregate on public links.
                ip6 saddr 2a0e:aa07:e220::/44 accept
                ip6 daddr 2a0e:aa07:e220::/44 accept
              ''}

              ${lib.optionalString (config.virtualisation.podman.enable or false) ''
                # Containers may initiate outbound traffic; new inbound traffic must
                # have been explicitly published and DNATed by Podman.
                iifname "podman*" accept
                oifname "podman*" ct status dnat accept
              ''}

              # Default-deny any forwarded traffic not allowed above.
              counter drop
          }
        '';
      };
    };

    deployment.healthChecks.requiredUnits = lib.optional config.networking.nftables.enable "nftables";
  };
}
