{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        mirroredBoots = [{ path = "/boot"; devices = [ "/dev/sda" "/dev/sdb" ]; }];
      };
    };

    growPartition = true;
    initrd = {
      availableKernelModules = [
        "uhci_hcd"
        "ehci_pci"
        "ahci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
        "raid1"
      ];
    };
    kernelModules = [ "kvm-intel" ];
    swraid.enable = true;
  };

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
