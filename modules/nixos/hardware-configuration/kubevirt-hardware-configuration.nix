{ config, lib, modulesPath, ... }:
##############################################################################
#
#  Template for KubeVirt's VM, mainly based on:
#    https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/kubevirt.nix
#
#  We write our hardware-configuration.nix, so that we can do some customization more easily.
#
#  the url above is used by `nixos-generator` to generate the KubeVirt's qcow2 image file.
#
##############################################################################
{
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  config = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    boot = {
      growPartition = true;
      kernelParams = [ "console=ttyS0" ];
      loader = {
        grub.device = "nodev";
        timeout = 0;
      };
    };

    services = {
      qemuGuest.enable = true;
      openssh.enable = true;
      cloud-init.enable = true;
    };
    deployment.healthChecks.requiredUnits = lib.optional config.services.qemuGuest.enable "qemu-guest-agent";
    systemd.services."serial-getty@ttyS0".enable = true;
  };
}
