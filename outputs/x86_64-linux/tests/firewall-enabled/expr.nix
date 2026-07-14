{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
  in
  {
    nftablesEnabled = config.networking.nftables.enable;
    legacyFirewallDisabled = config.networking.firewall.enable == false;
  }
)
