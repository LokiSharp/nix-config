{ pkgs
, self
, ...
}:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/deployment-state.prom";
  revision = self.rev or self.dirtyRev or "unknown";

  deploymentStateMetrics = pkgs.writeShellApplication {
    name = "deployment-state-metrics";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      revision=${builtins.toJSON revision}
      revision_file="$STATE_DIRECTORY/revision"
      timestamp_file="$STATE_DIRECTORY/deployed-at"

      previous_revision=""
      if [ -r "$revision_file" ]; then
        read -r previous_revision < "$revision_file" || previous_revision=""
      fi

      if [ "$previous_revision" != "$revision" ] || [ ! -s "$timestamp_file" ]; then
        printf '%s\n' "$revision" > "$revision_file.tmp"
        date +%s > "$timestamp_file.tmp"
        mv "$revision_file.tmp" "$revision_file"
        mv "$timestamp_file.tmp" "$timestamp_file"
      fi

      read -r deployed_at < "$timestamp_file"
      case "$deployed_at" in
        *[!0-9]* | "")
          echo "Invalid deployment timestamp: $deployed_at" >&2
          exit 1
          ;;
      esac

      profile_matches=0
      if [ "$(readlink -f /run/current-system)" = "$(readlink -f /nix/var/nix/profiles/system)" ]; then
        profile_matches=1
      fi

      tmp_file="$(mktemp ${metricsDirectory}/.deployment-state.XXXXXX)"
      trap 'rm -f "$tmp_file"' EXIT

      {
        echo "# HELP nixos_deployment_info Git revision used to build the active NixOS configuration."
        echo "# TYPE nixos_deployment_info gauge"
        printf 'nixos_deployment_info{revision="%s"} 1\n' "$revision"
        echo "# HELP nixos_deployment_timestamp_seconds Unix timestamp when this revision was first observed on the host."
        echo "# TYPE nixos_deployment_timestamp_seconds gauge"
        printf 'nixos_deployment_timestamp_seconds %s\n' "$deployed_at"
        echo "# HELP nixos_system_profile_matches_current Whether the system profile points to the active NixOS system."
        echo "# TYPE nixos_system_profile_matches_current gauge"
        printf 'nixos_system_profile_matches_current %s\n' "$profile_matches"
      } > "$tmp_file"

      chmod 0644 "$tmp_file"
      mv "$tmp_file" ${metricsFile}
      trap - EXIT
    '';
  };
in
{
  systemd = {
    services.deployment-state-metrics = {
      description = "Export NixOS deployment revision and profile state";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${deploymentStateMetrics}/bin/deployment-state-metrics";
        StateDirectory = "nixos-deployment-metrics";
        StateDirectoryMode = "0750";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ metricsDirectory ];
      };
    };

    timers.deployment-state-metrics = {
      description = "Refresh NixOS deployment revision and profile metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "15m";
        Persistent = true;
        RandomizedDelaySec = "30s";
      };
    };
  };

  deployment.healthChecks.requiredUnits = [ "deployment-state-metrics.timer" ];
}
