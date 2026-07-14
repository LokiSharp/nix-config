{ outputs, ... }:
let
  config = outputs.nixosConfigurations.Server-NixOS.config;
in
{
  enforceProfiles = config.modules.base.hardening."stage-2".enforceProfiles;
}
