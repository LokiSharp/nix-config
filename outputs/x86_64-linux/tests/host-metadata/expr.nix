{
  lib,
  mylib,
  ...
}:
let
  hosts = lib.attrValues mylib.hosts;
  vultr = mylib.hosts.vultr-jp;
  indexedHosts = lib.filter (
    host:
    host.networks.dn42.enable || host.networks.loki-net.enable || host.features.zerotier.nodeId != null
  ) hosts;
  dn42Hosts = lib.filter (host: host.networks.dn42.enable) hosts;
  lokiNetHosts = lib.filter (host: host.networks.loki-net.enable) hosts;
  zerotierHosts = lib.filter (host: host.features.zerotier.nodeId != null) hosts;

  isUnique = values: lib.length values == lib.length (lib.unique values);
  nonEmptyUnique = values: isUnique (lib.filter (value: value != "") values);
  legacyTags = [
    "server"
    "client"
    "vps"
    "dn42"
    "loki-net"
    "loki-net-edge"
    "firewall"
    "tailscale"
    "zerotier"
    "dn42-anycast-dns"
  ];
in
{
  allHostsValid = lib.all (host: host.validationErrors == [ ]) hosts;
  deploymentTagsUnique = lib.all (
    host: lib.length host.deploymentTags == lib.length (lib.unique host.deploymentTags)
  ) hosts;
  legacyDeploymentTagsAbsent = lib.all (
    host: lib.intersectLists legacyTags host.deploymentTags == [ ]
  ) hosts;

  globalUniqueness = {
    indexes = isUnique (map (host: host.index) indexedHosts);
    zerotierNodeIds = isUnique (map (host: host.features.zerotier.nodeId) zerotierHosts);
    slkNetIPv4 = isUnique (map (host: host.networks.slk-net.IPv4) indexedHosts);
    slkNetIPv6 = isUnique (map (host: host.networks.slk-net.IPv6) indexedHosts);
    dn42IPv4 = nonEmptyUnique (map (host: host.networks.dn42.IPv4) dn42Hosts);
    dn42IPv6 = nonEmptyUnique (map (host: host.networks.dn42.IPv6) dn42Hosts);
    lokiNetIPv4 = nonEmptyUnique (map (host: host.networks.loki-net.IPv4) lokiNetHosts);
    lokiNetIPv6 = nonEmptyUnique (map (host: host.networks.loki-net.IPv6) lokiNetHosts);
  };

  vultrMetadata = {
    inherit (vultr) role kind;
    firewall = vultr.features.firewall.enable;
    zerotierNodeId = vultr.features.zerotier.nodeId;
    dn42 = vultr.networks.dn42.enable;
    lokiNetRole = vultr.networks.loki-net.role;
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
