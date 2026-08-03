{ pkgs, ... }:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/reboot-required.prom";

  rebootRequiredMetrics = pkgs.writeShellApplication {
    name = "reboot-required-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      running_kernel="$(uname -r)"
      expected_kernel="$(
        find /run/current-system/kernel-modules/lib/modules \
          -mindepth 1 \
          -maxdepth 1 \
          -type d \
          -printf '%f\n'
      )"

      if [ -z "$expected_kernel" ] || [ "$(printf '%s\n' "$expected_kernel" | wc -l)" -ne 1 ]; then
        echo "Unable to determine exactly one kernel version from /run/current-system" >&2
        exit 1
      fi

      reboot_required=0
      if [ "$running_kernel" != "$expected_kernel" ]; then
        reboot_required=1
      fi

      tmp_file="$(mktemp ${metricsDirectory}/.reboot-required.XXXXXX)"
      trap 'rm -f "$tmp_file"' EXIT

      {
        echo "# HELP node_reboot_required Whether the running kernel differs from the current NixOS system kernel."
        echo "# TYPE node_reboot_required gauge"
        printf 'node_reboot_required %s\n' "$reboot_required"
      } > "$tmp_file"

      chmod 0644 "$tmp_file"
      mv "$tmp_file" ${metricsFile}
      trap - EXIT
    '';
  };
in
{
  systemd = {
    services.reboot-required-metrics = {
      description = "Export whether the current NixOS kernel requires a reboot";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${rebootRequiredMetrics}/bin/reboot-required-metrics";
      };
    };

    timers.reboot-required-metrics = {
      description = "Refresh the NixOS reboot-required metric";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "15m";
        Persistent = true;
        RandomizedDelaySec = "30s";
      };
    };
  };

  deployment.healthChecks.requiredUnits = [ "reboot-required-metrics.timer" ];
}
