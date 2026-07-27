{ lib
, inputs
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
lib.genAttrs publicHostNames (
  name:
  let
    host = mylib.hosts.${lib.toLower name};
    config = outputs.nixosConfigurations.${name}.config;
    nftRuleset = config.networking.nftables.tables.filter.content;
    sshPort = builtins.toString host.sshPort;
    sshRule = "tcp dport ${sshPort} accept";
    afterInputChain = builtins.elemAt (lib.splitString "chain input {" nftRuleset) 1;
    inputChain = builtins.elemAt (lib.splitString "# Allow all outgoing connections." afterInputChain) 0;
    sshRuleParts = lib.splitString sshRule inputChain;
    colmenaConfig = outputs.colmena.${name} { inherit name; };
    healthMetadata = inputs.self.deploymentHostMetadata.${name};
  in
  {
    sshServiceEnabled = config.services.openssh.enable;
    firewallFeatureEnabled = host.features.firewall.enable;
    opensshListensOnConfiguredPort = config.services.openssh.ports == [ host.sshPort ];
    deploymentTargetPortMatches = colmenaConfig.deployment.targetPort == host.sshPort;
    healthMetadataPortMatches = healthMetadata.sshPort == host.sshPort;
    nftablesEnabled = config.networking.nftables.enable;
    firewallAllowsConfiguredSshPort = lib.hasInfix sshRule inputChain;
    firewallRuleUnique = lib.length sshRuleParts == 2;
    firewallRuleBeforeFinalDrop =
      lib.length sshRuleParts == 2
      && lib.hasInfix "counter drop" (builtins.elemAt sshRuleParts 1);
  }
)
