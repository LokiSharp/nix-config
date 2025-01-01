{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  # Use the EFI boot loader.
  boot.loader.efi.canTouchEfiVariables = true;
  # depending on how you configured your disk mounts, change this to /boot or /boot/efi.
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.systemd-boot.enable = true;

  boot.growPartition = true;
  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  services.qemuGuest.enable = lib.mkDefault true;
  services.spice-vdagentd.enable = lib.mkDefault true;
  environment.systemPackages = with pkgs; [ virglrenderer ];
}
