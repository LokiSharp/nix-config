{ lib, ... }:

hosts:
let
  indexedHosts = lib.filter
    (
      host:
      host.features.zerotier.nodeId != null
      || host.networks.dn42.enable
      || host.networks.loki-net.enable
    )
    hosts;
  zerotierHosts = lib.filter (host: host.features.zerotier.nodeId != null) hosts;
  dn42Hosts = lib.filter (host: host.networks.dn42.enable) hosts;
  lokiNetHosts = lib.filter (host: host.networks.loki-net.enable) hosts;

  isUnique = values: lib.length values == lib.length (lib.unique values);
  nonEmptyUnique = values: isUnique (lib.filter (value: value != "") values);
in
lib.optional (!isUnique (map (host: host.index) indexedHosts)) "managed network indexes must be unique"
++ lib.optional
  (!isUnique (map (host: host.features.zerotier.nodeId) zerotierHosts))
  "ZeroTier node IDs must be unique"
++ lib.optional
  (!nonEmptyUnique (map (host: host.networks.dn42.IPv4) dn42Hosts))
  "DN42 IPv4 addresses must be unique"
++ lib.optional
  (!nonEmptyUnique (map (host: host.networks.dn42.IPv6) dn42Hosts))
  "DN42 IPv6 addresses must be unique"
++ lib.optional
  (!nonEmptyUnique (map (host: host.networks.loki-net.IPv4) lokiNetHosts))
  "Loki-Net IPv4 addresses must be unique"
++ lib.optional
  (!nonEmptyUnique (map (host: host.networks.loki-net.IPv6) lokiNetHosts))
  "Loki-Net IPv6 addresses must be unique"
