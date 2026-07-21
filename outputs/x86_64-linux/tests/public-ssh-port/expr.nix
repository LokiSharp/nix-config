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
lib.genAttrs publicHostNames (
  name:
  let
    host = mylib.hosts.${lib.toLower name};
    config = outputs.nixosConfigurations.${name}.config;
    nftRuleset = config.networking.nftables.ruleset;
    sshPort = builtins.toString host.sshPort;
  in
  {
    opensshListensOnConfiguredPort = config.services.openssh.ports == [ host.sshPort ];
    nftablesEnabled = config.networking.nftables.enable;
    firewallAllowsConfiguredSshPort = builtins.match ".*tcp dport ${sshPort} accept.*" nftRuleset != null;
  }
)
