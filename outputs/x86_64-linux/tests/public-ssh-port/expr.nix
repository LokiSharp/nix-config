{
  lib,
  mylib,
  outputs,
  ...
}:
let
  publicHostNames =
    lib.filter (
      name:
      let
        host = mylib.hosts.${lib.toLower name};
      in
      host.public.IPv4 != ""
    ) (builtins.attrNames outputs.nixosConfigurations);
in
lib.genAttrs publicHostNames (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
    nftRuleset = config.networking.nftables.ruleset;
  in
  {
    opensshListensOnPort22 = builtins.elem 22 config.services.openssh.ports;
    nftablesEnabled = config.networking.nftables.enable;
    firewallAllowsSshPort22 = builtins.match ".*tcp dport 22 accept.*" nftRuleset != null;
  }
)
