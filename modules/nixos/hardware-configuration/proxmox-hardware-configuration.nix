{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  # Use the EFI boot loader.
  boot = {
    loader = {
      efi = {
        canTouchEfiVariables = true;
        # depending on how you configured your disk mounts, change this to /boot or /boot/efi.
        efiSysMountPoint = "/boot";
      };
      systemd-boot.enable = true;
    };

    growPartition = true;
    initrd = {
      availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  services.qemuGuest.enable = lib.mkDefault true;
  deployment.healthChecks.requiredUnits = lib.optional config.services.qemuGuest.enable "qemu-guest-agent";
  services.spice-vdagentd.enable = lib.mkDefault true;
  environment.systemPackages = with pkgs; [ virglrenderer ];
}
