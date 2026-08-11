{ pkgs, ... }:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/reboot-required.prom";

  rebootRequiredMetrics = pkgs.writeShellApplication {
    name = "reboot-required-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
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

      booted_kernel_image="$(readlink -f /run/booted-system/kernel)"
      expected_kernel_image="$(readlink -f /run/current-system/kernel)"
      booted_initrd="$(readlink -f /run/booted-system/initrd)"
      expected_initrd="$(readlink -f /run/current-system/initrd)"
      booted_kernel_params="$(${pkgs.jq}/bin/jq -ce '."org.nixos.bootspec.v1".kernelParams' /run/booted-system/boot.json)"
      expected_kernel_params="$(${pkgs.jq}/bin/jq -ce '."org.nixos.bootspec.v1".kernelParams' /run/current-system/boot.json)"

      reboot_required=0
      reboot_reason="none"
      if [ "$running_kernel" != "$expected_kernel" ]; then
        reboot_required=1
        reboot_reason="kernel_version_mismatch"
      elif [ "$booted_kernel_image" != "$expected_kernel_image" ]; then
        reboot_required=1
        reboot_reason="kernel_build_mismatch"
      elif [ "$booted_kernel_params" != "$expected_kernel_params" ]; then
        reboot_required=1
        reboot_reason="kernel_parameters_mismatch"
      elif [ "$booted_initrd" != "$expected_initrd" ]; then
        reboot_required=1
        reboot_reason="initrd_mismatch"
      fi

      tmp_file="$(mktemp ${metricsDirectory}/.reboot-required.XXXXXX)"
      trap 'rm -f "$tmp_file"' EXIT

      {
        echo "# HELP node_reboot_required Whether the booted kernel state differs from the current NixOS system."
        echo "# TYPE node_reboot_required gauge"
        printf 'node_reboot_required{reason="%s",running_kernel="%s",expected_kernel="%s"} %s\n' \
          "$reboot_reason" "$running_kernel" "$expected_kernel" "$reboot_required"
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
      description = "Export whether the current NixOS system requires a reboot";
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
