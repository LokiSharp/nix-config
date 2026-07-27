{
  lib,
  mylib,
  ...
}:
let
  hosts = lib.attrValues mylib.hosts;
  vultr = mylib.hosts.vultr-jp;
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
  mkGlobalHost =
    {
      index,
      nodeId,
      dn42IPv4,
      dn42IPv6,
      lokiNetIPv4,
      lokiNetIPv6,
    }:
    {
      inherit index;
      features.zerotier = { inherit nodeId; };
      networks = {
        dn42 = {
          enable = dn42IPv4 != "" || dn42IPv6 != "";
          IPv4 = dn42IPv4;
          IPv6 = dn42IPv6;
        };
        loki-net = {
          enable = lokiNetIPv4 != "" || lokiNetIPv6 != "";
          IPv4 = lokiNetIPv4;
          IPv6 = lokiNetIPv6;
        };
      };
    };
  mkGlobalFixtureHost =
    index: nodeId: dn42IPv4: dn42IPv6: lokiNetIPv4: lokiNetIPv6:
    mkGlobalHost {
      inherit
        index
        nodeId
        dn42IPv4
        dn42IPv6
        lokiNetIPv4
        lokiNetIPv6
        ;
    };
  validGlobalErrors = mylib.globalHostValidationErrors [
    (mkGlobalFixtureHost 1 "0000000001" "172.20.0.1" "fd00::1" "10.0.0.1" "fd01::1")
    (mkGlobalFixtureHost 2 "0000000002" "172.20.0.2" "fd00::2" "10.0.0.2" "fd01::2")
  ];
  duplicateIndexErrors = mylib.globalHostValidationErrors [
    (mkGlobalFixtureHost 1 "0000000001" "" "" "" "")
    (mkGlobalFixtureHost 1 "0000000002" "" "" "" "")
  ];
  duplicateAddressErrors = mylib.globalHostValidationErrors [
    (mkGlobalFixtureHost 1 "0000000001" "172.20.0.1" "fd00::1" "10.0.0.1" "fd01::1")
    (mkGlobalFixtureHost 2 "0000000001" "172.20.0.1" "fd00::1" "10.0.0.1" "fd01::1")
  ];
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

  globalValidation = {
    validMetadataAccepted = validGlobalErrors == [ ];
    duplicateIndexRejected =
      builtins.elem "managed network indexes must be unique" duplicateIndexErrors;
    duplicateZerotierNodeIdRejected =
      builtins.elem "ZeroTier node IDs must be unique" duplicateAddressErrors;
    duplicateDn42IPv4Rejected =
      builtins.elem "DN42 IPv4 addresses must be unique" duplicateAddressErrors;
    duplicateDn42IPv6Rejected =
      builtins.elem "DN42 IPv6 addresses must be unique" duplicateAddressErrors;
    duplicateLokiNetIPv4Rejected =
      builtins.elem "Loki-Net IPv4 addresses must be unique" duplicateAddressErrors;
    duplicateLokiNetIPv6Rejected =
      builtins.elem "Loki-Net IPv6 addresses must be unique" duplicateAddressErrors;
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
