{
  lib,
  mylib,
  ...
}:
let
  vultr = mylib.hosts.vultr-jp;
in
{
  allHostsValid = lib.all (host: host.validationErrors == [ ]) (lib.attrValues mylib.hosts);
  deploymentTagsUnique = lib.all (
    host: lib.length host.deploymentTags == lib.length (lib.unique host.deploymentTags)
  ) (lib.attrValues mylib.hosts);

  vultrMetadata = {
    inherit (vultr) role kind;
    firewall = vultr.features.firewall.enable;
    zerotierNodeId = vultr.features.zerotier.nodeId;
    dn42 = vultr.networks.dn42.enable;
    lokiNetRole = vultr.networks.loki-net.role;
  };

  compatibilityTags = {
    server = vultr.hasTag mylib.tags.server;
    lokiNetEdge = vultr.hasTag mylib.tags.loki-net-edge;
  };

  namespacedDeploymentTags = {
    role = vultr.hasDeploymentTag "role:server";
    kind = vultr.hasDeploymentTag "kind:vps";
    network = vultr.hasDeploymentTag "net:loki-net";
    topology = vultr.hasDeploymentTag "topology:loki-net-edge";
  };

  freeFormDeploymentTags = {
    server = mylib.hosts.server-nixos.hasDeploymentTag "homelab-network";
    vm = mylib.hosts.vm-nixos.hasDeploymentTag "desktop";
  };
}
