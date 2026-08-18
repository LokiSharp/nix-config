{ mylib
, config
, lib
, ...
}:
let
  configLib = mylib.withConfig config;
in
{
  options.networking.nftables = {
    extraInputRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra inet filter input rules inserted before the default drop.
        Service modules should set this instead of opening a separate table.
      '';
    };
    extraForwardRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra inet filter forward rules inserted before the default drop.
        Service modules should set this instead of opening a separate table.
      '';
    };
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

              # accept traffic originated from us
              ct state {established, related} accept

              # ICMP
              # routers may also want: mld-listener-query, nd-router-solicit
              ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
              ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept

              # allow "ping"
              ip6 nexthdr icmpv6 icmpv6 type echo-request accept
              ip protocol icmp icmp type echo-request accept

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

              ${config.networking.nftables.extraForwardRules}

              # Default-deny any forwarded traffic not allowed above.
              counter drop
          }
        '';
      };
    };

    deployment.healthChecks.requiredUnits = lib.optional config.networking.nftables.enable "nftables";
  };
}
