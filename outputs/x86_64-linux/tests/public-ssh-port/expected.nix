{ lib
, mylib
, outputs
, ...
}:
let
  publicHostNames =
    lib.filter
      (
        name:
        let
          host = mylib.hosts.${lib.toLower name};
        in
        host.public.IPv4 != ""
      )
      (builtins.attrNames outputs.nixosConfigurations);
in
lib.genAttrs publicHostNames (_: {
  sshServiceEnabled = true;
  firewallFeatureEnabled = true;
  opensshListensOnConfiguredPort = true;
  deploymentTargetPortMatches = true;
  healthMetadataPortMatches = true;
  nftablesEnabled = true;
  firewallAllowsConfiguredSshPort = true;
  firewallRuleUnique = true;
  firewallRuleBeforeFinalDrop = true;
})
