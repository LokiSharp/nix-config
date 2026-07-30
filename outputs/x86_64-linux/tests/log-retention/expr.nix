{ lib, outputs, ... }:

lib.mapAttrs
  (
    name: system:
    let
      inherit (system) config;
      journaldConfig = config.services.journald.extraConfig;
      coredumpConfig = config.systemd.coredump.settings.Coredump;
    in
    {
      journaldBounded =
        if name == "Lycheen-US-SLC" then
          lib.all (setting: lib.hasInfix setting journaldConfig) [
            "Storage=volatile"
            "RuntimeMaxUse=64M"
            "RuntimeMaxFileSize=16M"
            "MaxRetentionSec=1day"
          ]
        else
          lib.all (setting: lib.hasInfix setting journaldConfig) [
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
