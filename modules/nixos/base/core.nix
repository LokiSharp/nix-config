{ lib, ... }:
{
  boot.loader.systemd-boot = {
    # we use Git for version control, so we don't need to keep too many generations.
    configurationLimit = lib.mkDefault 10;
    # pick the highest resolution for systemd-boot's console.
    consoleMode = lib.mkDefault "max";
  };

  boot.loader.timeout = lib.mkDefault 8; # wait for x seconds to select the boot entry

  # for power management
  services = {
    power-profiles-daemon = {
      enable = true;
    };
    upower.enable = true;
  };

  # Global Stage 1 Hardening
  modules.base.hardening.enable = lib.mkDefault true;

  # Limit journald log size
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=256M
    MaxRetentionSec=1month
  '';

  # Assign a higher OOM survival priority to SSH
  systemd.services.sshd.serviceConfig.OOMScoreAdjust = -1000;

  # Enable zramSwap to delay physical memory exhaustion
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Use up to 50% of memory for compressed swap
  };
}
