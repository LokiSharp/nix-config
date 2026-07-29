{ lib
, mylib
, outputs
, ...
}:
let
  config = outputs.nixosConfigurations.MoeDove-TPE.config;
  secretNames = builtins.attrNames config.sops.secrets;
  sysctlNames = builtins.attrNames config.boot.kernel.sysctl;
in
{
  roleIsMember = mylib.hosts.moedove-tpe.networks.loki-net.role == "member";
  externalPeersAbsent = config.services.loki-net == { };
  externalPeerSecretsAbsent = lib.all
    (name: !(builtins.elem name secretNames))
    [
      "bird-bgp-password"
      "chief-rs-password"
      "tpix-rs-password"
    ];
  ixpNetworksAbsent = lib.all
    (name: !(builtins.hasAttr name config.systemd.network.networks))
    [
      "20-wan-chief"
      "20-wan-tpix"
    ];
  ixpSysctlsAbsent = lib.all
    (
      name:
      !(lib.hasInfix ".ens19." name)
      && !(lib.hasInfix ".ens20." name)
    )
    sysctlNames;
}
