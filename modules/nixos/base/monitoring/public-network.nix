{ config, lib, pkgs, ... }:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/public-network.prom";
  rulesFile = pkgs.writeText "public-network-rules.sh" (builtins.readFile ./public-network-rules.sh);
  podmanEnabled = config.virtualisation.podman.enable or false;

  wakeAccounting = pkgs.writeShellScript "public-network-accounting-wake" ''
    # nft -f has already replaced inet filter. Wake the collector now so
    # the wiped counters and rules are rebuilt before the next 30s sleep.
    ${pkgs.systemd}/bin/systemctl kill --kill-who=main -s SIGUSR1 public-network-accounting.service || true
  '';

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
    ] ++ lib.optionals podmanEnabled [
      pkgs.podman
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      # shellcheck disable=SC1091
      source ${rulesFile}

      metrics_file=${metricsFile}
      names_file=/var/lib/public-network-accounting/units.tsv
      podman_enabled=${if podmanEnabled then "1" else "0"}
      declare -A unit_by_safe=()
      declare -A counter_bytes=()
      declare -A id_by_safe=()
      declare -A want_comment=()
      declare -A want_unit=()
      next_mark_id=1
      pending=0
      sleeper=0
      uplinks=()

      trap 'pending=1; if [ "$sleeper" != 0 ]; then kill "$sleeper" 2>/dev/null || true; fi' USR1

      load_names() {
        local safe unit
        unit_by_safe=()
        [ -f "$names_file" ] || return 0
        while IFS=$'\t' read -r safe unit; do
          [ -n "$safe" ] || continue
          unit_by_safe["$safe"]="$unit"
        done < "$names_file"
      }

      save_names() {
        local tmp safe
        mkdir -p "$(dirname "$names_file")"
        tmp="$(mktemp "$(dirname "$names_file")/.units.XXXXXX")"
        for safe in "''${!unit_by_safe[@]}"; do
          printf '%s\t%s\n' "$safe" "''${unit_by_safe[$safe]}"
        done | sort > "$tmp"
        mv "$tmp" "$names_file"
      }

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

      # Host end of a container veth. Reject the bridge and every overlay.
      is_container_peer() {
        case "$1" in
          lo|dummy*|zt*|tailscale*|dn42*|wg*|docker*|br-*|cni*|virbr*|podman*|sit*|erspan*|ip6tnl*|ifb*|ve-*)
            return 1
            ;;
          *)
            return 0
            ;;
        esac
      }

      ensure_sets() {
        local table_json="$1"
        set_missing() {
          ! jq -e --arg name "$1" 'any(.nftables[]; .set.family == "inet" and .set.table == "filter" and .set.name == $name)' "$table_json" >/dev/null
        }
        if ! jq -e 'any(.nftables[]; .table.family == "inet" and .table.name == "filter")' "$table_json" >/dev/null; then
          echo "inet filter is not loaded; skip public network accounting" >&2
          return 1
        fi
        if set_missing pubacct_uplink; then
          nft add set inet filter pubacct_uplink '{ type ifname; }'
        fi
        if set_missing pubacct_private4; then
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
        # fc00::/7 already contains DN42 and the SLK ULA fdbc:f9dc:67ad::/48.
        # Adding that /48 beside it makes the interval set overlap.
        if set_missing pubacct_private6; then
          nft add set inet filter pubacct_private6 '{
            type ipv6_addr; flags interval;
            elements = {
              ::/128, ::1/128, 64:ff9b::/96, 100::/64, 2001:db8::/32,
              fc00::/7, fe80::/10, ff00::/8
            };
          }'
        fi
      }

      ensure_bridge_chain() {
        local table_json="$1"
        if jq -e 'any(.nftables[]; .chain.family == "bridge" and .chain.table == "pubacct" and .chain.name == "from_container")' "$table_json" >/dev/null; then
          return 0
        fi
        nft add table bridge pubacct 2>/dev/null || true
        nft add chain bridge pubacct from_container '{ type filter hook input priority 0; policy accept; }'
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

      service_from_cgroup() {
        local cg="$1"
        printf '%s\n' "$cg" | awk -F/ '{
          u = ""
          for (i = 1; i <= NF; i++) if ($i ~ /\.service$/) u = $i
          print u
        }'
      }

      # Rootful containers are moved into machine.slice/libpod-*.scope, so the
      # service is either the podman label or the conmon parent cgroup.
      container_unit() {
        local id="$1" pid="$2" label cur unit hops
        label="$(podman inspect --format '{{index .Config.Labels "PODMAN_SYSTEMD_UNIT"}}' "$id" 2>/dev/null || true)"
        case "$label" in
          "" | "<no value>") ;;
          *)
            printf '%s\n' "$label"
            return 0
            ;;
        esac
        cur="$pid"
        hops=0
        while [ "$hops" -lt 8 ]; do
          [ -r "/proc/$cur/cgroup" ] || return 1
          unit="$(service_from_cgroup "$(<"/proc/$cur/cgroup")")"
          if [ -n "$unit" ]; then
            printf '%s\n' "$unit"
            return 0
          fi
          cur="$(awk '/^PPid:/ { print $2 }' "/proc/$cur/status")"
          [ -n "$cur" ] || return 1
          [ "$cur" = 1 ] && return 1
          hops=$((hops + 1))
        done
        return 1
      }

      add_cgroup_rules() {
        local units_file="$1" plan="$2"
        local unit cgroup base level safe dir chain counter family comment
        while read -r unit _; do
          [ -n "$unit" ] || continue
          cgroup="$(systemctl show -p ControlGroup --value "$unit" 2>/dev/null || true)"
          [ -n "$cgroup" ] || continue
          base="''${cgroup#/}"
          [ -n "$base" ] || continue
          level="$(printf '%s\n' "$base" | awk -F/ '{ print NF }')"
          [ "$level" -ge 1 ] || continue
          safe="$(safe_id "$unit")"
          want_unit["$safe"]="$unit"
          for dir in tx rx; do
            if [ "$dir" = tx ]; then
              chain=output
            else
              chain=input
            fi
            counter="''${dir}-''${safe}"
            for family in 4 6; do
              comment="pubacct-v1|''${dir}|''${level}|''${unit}|''${family}"
              if [ -z "''${want_comment[$comment]+x}" ]; then
                want_comment["$comment"]=1
                printf 'cgroup\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                  "$chain" "$level" "$base" "$counter" "$comment" "$family" >> "$plan"
              fi
            done
          done
        done < "$units_file"
      }

      add_bridge_rules() {
        local plan="$1" host_links="$2" ids_file="$3"
        local id mode pid unit safe mark peer ifname dir counter family comment stamped
        declare -A seen_if=()
        while read -r id; do
          [ -n "$id" ] || continue
          mode="$(podman inspect --format '{{.HostConfig.NetworkMode}}' "$id" 2>/dev/null || true)"
          case "$mode" in
            "" | host | none | pasta | slirp4netns | container:*)
              continue
              ;;
          esac
          pid="$(podman inspect --format '{{.State.Pid}}' "$id" 2>/dev/null || true)"
          case "$pid" in
            "" | 0) continue ;;
          esac
          unit="$(container_unit "$id" "$pid" || true)"
          [ -n "$unit" ] || continue
          safe="$(safe_id "$unit")"
          want_unit["$safe"]="$unit"
          if [ -z "''${id_by_safe[$safe]+x}" ]; then
            if [ "$next_mark_id" -gt 255 ]; then
              echo "public network accounting ran out of container mark ids" >&2
              continue
            fi
            id_by_safe["$safe"]="$next_mark_id"
            next_mark_id=$((next_mark_id + 1))
          fi
          mark="''${id_by_safe[$safe]}"
          stamped=0
          while read -r peer; do
            [ -n "$peer" ] || continue
            ifname="$(jq -r --argjson idx "$peer" 'map(select(.ifindex == $idx)) | .[0].ifname // empty' "$host_links")"
            [ -n "$ifname" ] || continue
            is_container_peer "$ifname" || continue
            if [ -n "''${seen_if[$ifname]+x}" ]; then
              continue
            fi
            seen_if["$ifname"]="$unit"
            comment="pubacct-v1|mark|''${mark}|''${unit}|''${ifname}"
            if [ -z "''${want_comment[$comment]+x}" ]; then
              want_comment["$comment"]=1
              printf 'stamp\t%s\t%s\t%s\n' "$ifname" "$mark" "$comment" >> "$plan"
            fi
            stamped=1
          done < <(nsenter -t "$pid" -n ip -j link show 2>/dev/null | jq -r '.[] | (.link_index // empty)' || true)
          [ "$stamped" -eq 1 ] || continue
          for dir in tx rx; do
            counter="''${dir}-''${safe}"
            for family in 4 6; do
              comment="pubacct-v1|fwd|''${dir}|''${family}|''${unit}|''${mark}"
              if [ -z "''${want_comment[$comment]+x}" ]; then
                want_comment["$comment"]=1
                printf 'forward\t%s\t%s\t%s\t%s\t%s\n' \
                  "$mark" "$counter" "$comment" "$family" "$dir" >> "$plan"
              fi
            done
          done
        done < "$ids_file"
      }

      sync_once() {
        local table_json units_file plan host_links ids_file
        local family table chain handle comment kind safe name dir
        local -a drop_rules=()
        local -a drop_counters=()
        declare -A have_comment=()
        declare -A old_units=()
        declare -gA want_comment=()
        declare -gA want_unit=()

        table_json="$(mktemp)"
        units_file="$(mktemp)"
        plan="$(mktemp)"
        host_links=""
        ids_file=""
        if ! nft -j list ruleset > "$table_json"; then
          echo "nft list ruleset failed" >&2
          rm -f "$table_json" "$units_file" "$plan"
          return 1
        fi
        if ! ensure_sets "$table_json"; then
          rm -f "$table_json" "$units_file" "$plan"
          return 1
        fi
        if ! mapfile -t uplinks < <(refresh_uplinks); then
          uplinks=()
        fi
        if ! systemctl list-units --type=service --state=running --no-legend --plain --no-pager > "$units_file"; then
          echo "systemctl list-units failed; keep existing public network rules" >&2
          rm -f "$table_json" "$units_file" "$plan"
          return 1
        fi
        : > "$plan"
        add_cgroup_rules "$units_file" "$plan"

        if [ "$podman_enabled" = 1 ]; then
          host_links="$(mktemp)"
          ids_file="$(mktemp)"
          if ! ip -j link show > "$host_links"; then
            echo "ip link failed; keep existing public network rules" >&2
            rm -f "$table_json" "$units_file" "$plan" "$host_links" "$ids_file"
            return 1
          fi
          if ! podman ps -q > "$ids_file"; then
            echo "podman ps failed; keep existing public network rules" >&2
            rm -f "$table_json" "$units_file" "$plan" "$host_links" "$ids_file"
            return 1
          fi
          if ! ensure_bridge_chain "$table_json"; then
            echo "failed to create the container accounting chain; keep existing rules" >&2
            rm -f "$table_json" "$units_file" "$plan" "$host_links" "$ids_file"
            return 1
          fi
          add_bridge_rules "$plan" "$host_links" "$ids_file"
        fi

        while IFS=$'\t' read -r family table chain handle comment; do
          [ -n "''${comment:-}" ] || continue
          case "$comment" in
            pubacct-*)
              if [ -z "''${want_comment[$comment]+x}" ] || [ -n "''${have_comment[$comment]+x}" ]; then
                drop_rules+=("$family"$'\t'"$table"$'\t'"$chain"$'\t'"$handle")
              else
                have_comment["$comment"]=1
              fi
              ;;
          esac
        done < <(
          jq -r '
            .nftables[]
            | select(.rule.comment != null)
            | select(.rule.comment | startswith("pubacct"))
            | [.rule.family, .rule.table, .rule.chain, .rule.handle, .rule.comment]
            | @tsv
          ' "$table_json"
        )

        for kind in "''${drop_rules[@]}"; do
          IFS=$'\t' read -r family table chain handle <<< "$kind"
          if ! nft delete rule "$family" "$table" "$chain" handle "$handle"; then
            echo "failed to delete public network rule $family $table $chain $handle" >&2
          fi
        done

        declare -gA counter_bytes=()
        while read -r kind comment; do
          [ -n "$kind" ] || continue
          counter_bytes["$kind"]="$comment"
        done < <(
          jq -r '
            .nftables[]
            | select(.counter != null)
            | select(.counter.family == "inet" and .counter.table == "filter")
            | select(.counter.name | test("^(tx|rx)-"))
            | "\(.counter.name) \(.counter.bytes)"
          ' "$table_json"
        )

        for safe in "''${!want_unit[@]}"; do
          for dir in tx rx; do
            name="''${dir}-''${safe}"
            if [ -z "''${counter_bytes[$name]+x}" ]; then
              if nft add counter inet filter "$name" >/dev/null; then
                counter_bytes["$name"]=0
              else
                echo "failed to add public network counter $name" >&2
              fi
            fi
          done
        done
        for name in "''${!counter_bytes[@]}"; do
          safe="''${name#*-}"
          if [ -z "''${want_unit[$safe]+x}" ]; then
            drop_counters+=("$name")
          fi
        done
        for name in "''${drop_counters[@]}"; do
          if nft delete counter inet filter "$name"; then
            unset "counter_bytes[$name]"
          else
            echo "failed to delete public network counter $name" >&2
          fi
        done

        while IFS=$'\t' read -r kind a b c d e f; do
          [ -n "$kind" ] || continue
          case "$kind" in
            cgroup)
              comment="$e"
              [ -n "''${have_comment[$comment]+x}" ] && continue
              if ! apply_argv < <(cgroup_insert_argv "$a" "$b" "$c" "$d" "$comment" "$f"); then
                echo "failed to insert cgroup rule $comment" >&2
              fi
              ;;
            stamp)
              comment="$c"
              [ -n "''${have_comment[$comment]+x}" ] && continue
              if ! apply_argv < <(mark_stamp_argv "$a" "$b" "$comment"); then
                echo "failed to insert container mark rule $comment" >&2
              fi
              ;;
            forward)
              comment="$c"
              [ -n "''${have_comment[$comment]+x}" ] && continue
              if ! apply_argv < <(forward_insert_argv "$a" "$b" "$comment" "$d" "$e"); then
                echo "failed to insert forward rule $comment" >&2
              fi
              ;;
          esac
        done < "$plan"

        for safe in "''${!unit_by_safe[@]}"; do
          old_units["$safe"]="''${unit_by_safe[$safe]}"
        done
        declare -gA unit_by_safe=()
        for safe in "''${!want_unit[@]}"; do
          unit_by_safe["$safe"]="''${want_unit[$safe]}"
        done
        # A counter that is still referenced could not be deleted. Keep its
        # previous label so the series does not flip to the encoded id.
        for name in "''${!counter_bytes[@]}"; do
          safe="''${name#*-}"
          if [ -z "''${unit_by_safe[$safe]+x}" ] && [ -n "''${old_units[$safe]+x}" ]; then
            unit_by_safe["$safe"]="''${old_units[$safe]}"
          fi
        done
        save_names
        write_metrics
        rm -f "$table_json" "$units_file" "$plan"
        if [ -n "$host_links" ]; then
          rm -f "$host_links"
        fi
        if [ -n "$ids_file" ]; then
          rm -f "$ids_file"
        fi
      }

      write_metrics() {
        local tmp name direction unit bytes dev safe
        tmp="$(mktemp ${metricsDirectory}/.public-network.XXXXXX)"
        {
          echo "# HELP node_public_network_uplink_present Whether a non-overlay default route is being accounted."
          echo "# TYPE node_public_network_uplink_present gauge"
          if [ "''${#uplinks[@]}" -gt 0 ]; then
            echo "node_public_network_uplink_present 1"
          else
            echo "node_public_network_uplink_present 0"
          fi
          echo "# HELP node_public_network_uplink_info Public uplink interfaces included in per-service accounting."
          echo "# TYPE node_public_network_uplink_info gauge"
          for dev in "''${uplinks[@]}"; do
            [ -n "$dev" ] || continue
            printf 'node_public_network_uplink_info{device="%s"} 1\n' "$dev"
          done
          echo "# HELP node_public_network_bytes_total Bytes to or from public addresses on non-overlay default-route interfaces, by systemd service."
          echo "# TYPE node_public_network_bytes_total counter"
          for name in "''${!counter_bytes[@]}"; do
            case "$name" in
              tx-* | rx-*) ;;
              *) continue ;;
            esac
            direction="''${name%%-*}"
            safe="''${name#*-}"
            if [ -n "''${unit_by_safe[$safe]+x}" ]; then
              unit="''${unit_by_safe[$safe]}"
            else
              unit="$safe"
            fi
            bytes="''${counter_bytes[$name]}"
            unit="''${unit//\\/\\\\}"
            unit="''${unit//\"/\\\"}"
            printf 'node_public_network_bytes_total{unit="%s",direction="%s"} %s\n' \
              "$unit" "$direction" "$bytes"
          done
        } > "$tmp"
        chmod 0644 "$tmp"
        mv "$tmp" "$metrics_file"
      }

      load_names || true

      while true; do
        if ! sync_once; then
          echo "public network accounting sync failed" >&2
        fi
        if [ "$pending" = 1 ]; then
          pending=0
          continue
        fi
        sleep 30 &
        sleeper=$!
        if [ "$pending" = 1 ]; then
          kill "$sleeper" 2>/dev/null || true
        fi
        wait "$sleeper" || true
        sleeper=0
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
      StateDirectory = "public-network-accounting";
    };
  };

  systemd.services.nftables.serviceConfig = lib.mkIf config.networking.nftables.enable {
    ExecStart = lib.mkAfter [ wakeAccounting ];
    ExecReload = lib.mkAfter [ wakeAccounting ];
  };

  deployment.healthChecks.requiredUnits = [ "public-network-accounting.service" ];
}
