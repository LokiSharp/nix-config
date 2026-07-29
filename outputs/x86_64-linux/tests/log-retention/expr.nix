{ lib, outputs, ... }:

lib.mapAttrs
  (
    _name: system:
    let
      inherit (system) config;
      journaldConfig = config.services.journald.extraConfig;
      coredumpConfig = config.systemd.coredump.settings.Coredump;
    in
    {
      journaldBounded = lib.all (setting: lib.hasInfix setting journaldConfig) [
        "SystemMaxUse=256M"
        "SystemKeepFree=1G"
        "SystemMaxFileSize=32M"
        "RuntimeMaxUse=64M"
        "RuntimeMaxFileSize=16M"
        "MaxRetentionSec=2week"
      ];
      coredumpsBounded =
        coredumpConfig == {
          Storage = "external";
          Compress = true;
          ProcessSizeMax = "1G";
          ExternalSizeMax = "128M";
          MaxUse = "256M";
          KeepFree = "1G";
        };
    }
  )
  outputs.nixosConfigurations
