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
  evalHost =
    module:
    (lib.evalModules {
      modules = [
        (mylib.relativeToRoot "lib/host-options.nix")
        module
      ];
      specialArgs.name = "validation-fixture";
    }).config;
  missingIndexHost = evalHost {
    role = "client";
    kind = "vm";
    features.zerotier = {
      enable = true;
      nodeId = "0123456789";
    };
  };
  outOfRangeHost = evalHost {
    index = 255;
    role = "client";
    kind = "vm";
  };
  mismatchedSlkHost = evalHost {
    index = 13;
    role = "client";
    kind = "vm";
    networks.slk-net.IPv4 = "198.18.0.14";
  };
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
  deploymentTagsUnique = lib.all (
    host: lib.length host.deploymentTags == lib.length (lib.unique host.deploymentTags)
  ) hosts;
  legacyDeploymentTagsAbsent = lib.all (
    host: lib.intersectLists legacyTags host.deploymentTags == [ ]
  ) hosts;

  indexValidation = {
    missingIndexRejected = builtins.elem "index is required for managed network members" missingIndexHost.validationErrors;
    outOfRangeRejected = builtins.elem "index must be between 1 and 254" outOfRangeHost.validationErrors;
    mismatchedAddressRejected =
      builtins.elem "networks.slk-net.IPv4 must match the host index" mismatchedSlkHost.validationErrors;
  };

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
