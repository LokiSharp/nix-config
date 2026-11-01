{ pkgs, ... }:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/public-network.prom";

  # One host-wide collector. It keeps per-service counters in the existing
  # inet filter table. Those counters are nft objects, not systemd services.
  # Rules are inserted ahead of the firewall verdict so an earlier accept
  # cannot hide the packet, and they carry no verdict of their own.
  publicNetworkAccounting = pkgs.writeShellApplication {
    name = "public-network-accounting";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.iproute2
      pkgs.jq
      pkgs.nftables
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      metrics_file=${metricsFile}

      is_overlay() {
        case "$1" in
          lo|dummy*|zt*|tailscale*|dn42*|wg*|docker*|veth*|br-*|cni*|virbr*|podman*|sit*|erspan*|ip6tnl*|ifb*|ve-*)
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      ensure_sets() {
        if ! nft list table inet filter >/dev/null 2>&1; then
          echo "inet filter is not loaded; skip public network accounting" >&2
          return 1
        fi
        if ! nft list set inet filter pubacct_uplink >/dev/null 2>&1; then
          nft add set inet filter pubacct_uplink '{ type ifname; }'
        fi
        if ! nft list set inet filter pubacct_private4 >/dev/null 2>&1; then
          nft add set inet filter pubacct_private4 '{
            type ipv4_addr; flags interval;
            elements = {
              0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8,
              169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24,
              192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24,
              203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4
            };
          }'
        fi
        if ! nft list set inet filter pubacct_private6 >/dev/null 2>&1; then
          nft add set inet filter pubacct_private6 '{
            type ipv6_addr; flags interval;
            elements = {
              ::/128, ::1/128, 64:ff9b::/96, 100::/64, 2001:db8::/32,
              fc00::/7, fe80::/10, ff00::/8
            };
          }'
        fi
      }

      refresh_uplinks() {
        local dev
        nft flush set inet filter pubacct_uplink
        while IFS= read -r dev; do
          [ -n "$dev" ] || continue
          if is_overlay "$dev"; then
            continue
          fi
          nft add element inet filter pubacct_uplink "{ \"$dev\" }"
          printf '%s\n' "$dev"
        done < <(
          {
            ip -j route show default 2>/dev/null || printf '[]\n'
            ip -j -6 route show default 2>/dev/null || printf '[]\n'
          } | jq -rs '[.[][]?.dev // empty] | unique | .[]'
        )
      }

      list_rule_comments() {
        local chain
        for chain in output input; do
          nft -j list chain inet filter "$chain" | jq -r --arg chain "$chain" '
            .nftables[]
            | select(.rule != null)
            | .rule
            | select(.comment != null)
            | "\($chain) \(.handle) \(.comment)"
          '
        done
      }

      sync_rules() {
        local unit cgroup level base counter comment family dir chain
        local -a units=()
        local -a match=()
        declare -A want=()

        while read -r unit _; do
          [ -n "$unit" ] || continue
          units+=("$unit")
        done < <(systemctl list-units --type=service --state=running --no-legend --plain --no-pager)

        for unit in "''${units[@]}"; do
          cgroup="$(systemctl show -p ControlGroup --value "$unit" 2>/dev/null || true)"
          [ -n "$cgroup" ] || continue
          level="$(printf '%s\n' "$cgroup" | awk -F/ '{print NF-1}')"
          [ "$level" -ge 1 ] || continue
          for dir in tx rx; do
            counter="''${dir}-''${unit}"
            if ! nft list counter inet filter "$counter" >/dev/null 2>&1; then
              nft add counter inet filter "$counter" >/dev/null
            fi
            for family in 4 6; do
              want["pubacct-v1|''${dir}|''${level}|''${unit}|''${family}"]=1
            done
          done
        done

        while read -r chain handle comment; do
          [ -n "''${comment:-}" ] || continue
          case "$comment" in
            pubacct-v1\|*)
              if [ -z "''${want[$comment]+x}" ]; then
                nft delete rule inet filter "$chain" handle "$handle"
              fi
              ;;
            pubacct-*)
              nft delete rule inet filter "$chain" handle "$handle"
              ;;
          esac
        done < <(list_rule_comments)

        for unit in "''${units[@]}"; do
          cgroup="$(systemctl show -p ControlGroup --value "$unit" 2>/dev/null || true)"
          [ -n "$cgroup" ] || continue
          level="$(printf '%s\n' "$cgroup" | awk -F/ '{print NF-1}')"
          # nft looks up the cgroup path. The level is the component count.
          base="''${cgroup#/}"
          [ "$level" -ge 1 ] || continue
          for dir in tx rx; do
            if [ "$dir" = tx ]; then
              chain=output
            else
              chain=input
            fi
            counter="''${dir}-''${unit}"
            for family in 4 6; do
              comment="pubacct-v1|''${dir}|''${level}|''${unit}|''${family}"
              if list_rule_comments | awk -v want="$comment" '$3 == want { found = 1 } END { exit !found }'; then
                continue
              fi
              if [ "$dir" = tx ] && [ "$family" = 4 ]; then
                match=(oifname @pubacct_uplink ip daddr "!=" @pubacct_private4)
              elif [ "$dir" = tx ]; then
                match=(oifname @pubacct_uplink ip6 daddr "!=" @pubacct_private6)
              elif [ "$family" = 4 ]; then
                match=(iifname @pubacct_uplink ip saddr "!=" @pubacct_private4)
              else
                match=(iifname @pubacct_uplink ip6 saddr "!=" @pubacct_private6)
              fi
              nft insert rule inet filter "$chain" \
                "''${match[@]}" \
                socket cgroupv2 level "$level" "$base" \
                counter name "$counter" \
                comment "$comment"
            done
          done
        done
      }

      write_metrics() {
        local tmp name direction unit bytes dev
        tmp="$(mktemp ${metricsDirectory}/.public-network.XXXXXX)"
        {
          echo "# HELP node_public_network_uplink_present Whether a non-overlay default route is being accounted."
          echo "# TYPE node_public_network_uplink_present gauge"
          if [ "$1" -gt 0 ]; then
            echo "node_public_network_uplink_present 1"
          else
            echo "node_public_network_uplink_present 0"
          fi
          echo "# HELP node_public_network_uplink_info Public uplink interfaces included in per-service accounting."
          echo "# TYPE node_public_network_uplink_info gauge"
          shift
          for dev in "$@"; do
            [ -n "$dev" ] || continue
            printf 'node_public_network_uplink_info{device="%s"} 1\n' "$dev"
          done
          echo "# HELP node_public_network_bytes_total Bytes to or from public addresses on non-overlay default-route interfaces, by systemd service."
          echo "# TYPE node_public_network_bytes_total counter"
          while read -r name bytes; do
            case "$name" in
              tx-*|rx-*) ;;
              *) continue ;;
            esac
            direction="''${name%%-*}"
            unit="''${name#*-}"
            unit="''${unit//\\/\\\\}"
            unit="''${unit//\"/\\\"}"
            printf 'node_public_network_bytes_total{unit="%s",direction="%s"} %s\n' \
              "$unit" "$direction" "$bytes"
          done < <(
            nft -j list counters table inet filter | jq -r '
              .nftables[]
              | select(.counter != null)
              | .counter
              | "\(.name) \(.bytes)"
            '
          )
        } > "$tmp"
        chmod 0644 "$tmp"
        mv "$tmp" "$metrics_file"
      }

      while true; do
        if ensure_sets; then
          mapfile -t uplinks < <(refresh_uplinks || true)
          if ! sync_rules; then
            echo "public network accounting rule sync failed" >&2
          fi
          write_metrics "''${#uplinks[@]}" "''${uplinks[@]}" \
            || echo "public network accounting metric write failed" >&2
        fi
        sleep 30
      done
    '';
  };
in
{
  systemd.services.public-network-accounting = {
    description = "Account public network bytes for each systemd service";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "nftables.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${publicNetworkAccounting}/bin/public-network-accounting";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  deployment.healthChecks.requiredUnits = [ "public-network-accounting.service" ];
}
