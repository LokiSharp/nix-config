{ pkgs, ... }:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/coredumps.prom";

  coredumpMetrics = pkgs.writeShellApplication {
    name = "coredump-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    text = ''
      coredump_log="$(
        journalctl \
          --identifier=systemd-coredump \
          --since="-24 hours" \
          --no-pager \
          --output=cat
      )"

      total="$(
        printf '%s\n' "$coredump_log" |
          grep --count --extended-regexp 'dumped core\.$' || true
      )"
      journald="$(
        printf '%s\n' "$coredump_log" |
          grep --count --extended-regexp 'Process .+ \(systemd-journal\).+ dumped core\.$' || true
      )"

      tmp_file="$(mktemp ${metricsDirectory}/.coredumps.XXXXXX)"
      trap 'rm -f "$tmp_file"' EXIT

      {
        echo "# HELP nixos_coredumps_24h Number of coredumps recorded during the last 24 hours."
        echo "# TYPE nixos_coredumps_24h gauge"
        printf 'nixos_coredumps_24h %s\n' "$total"
        echo "# HELP nixos_journald_coredumps_24h Number of systemd-journald coredumps recorded during the last 24 hours."
        echo "# TYPE nixos_journald_coredumps_24h gauge"
        printf 'nixos_journald_coredumps_24h %s\n' "$journald"
      } > "$tmp_file"

      chmod 0644 "$tmp_file"
      mv "$tmp_file" ${metricsFile}
      trap - EXIT
    '';
  };
in
{
  systemd = {
    services.coredump-metrics = {
      description = "Export recent coredump metrics";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${coredumpMetrics}/bin/coredump-metrics";
      };
    };

    timers.coredump-metrics = {
      description = "Refresh recent coredump metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "5m";
        Persistent = true;
        RandomizedDelaySec = "30s";
      };
    };
  };

  deployment.healthChecks.requiredUnits = [ "coredump-metrics.timer" ];
}
