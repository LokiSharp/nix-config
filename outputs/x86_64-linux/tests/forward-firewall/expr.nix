{ lib
, mylib
, outputs
, ...
}:

lib.mapAttrs
  (
    name: system:
    let
      host = mylib.hosts.${lib.toLower name};
      config = system.config;
      ruleset = config.networking.nftables.tables.filter.content;
      hasRule = rule: lib.hasInfix rule ruleset;
    in
    {
      dropsInvalidTraffic = hasRule "ct state invalid drop";
      allowsEstablishedTraffic = hasRule "ct state { established, related } accept";
      defaultDeny = hasRule "# Default-deny any forwarded traffic not allowed above.";
      noUnconditionalForwardAccept = !(hasRule "Routing, Kubernetes, and Podman hosts need forwarded traffic.");
      zerotierScoped = !host.features.zerotier.enable || hasRule ''iifname "zt-slk0" accept'';
      dn42Scoped = !host.networks.dn42.enable || hasRule ''iifname "dn42-*" accept'';
      tailscaleScoped = !host.features.tailscale.enable || hasRule ''iifname "tailscale0" accept'';
      lokiNetScoped = !host.networks.loki-net.enable || hasRule "ip6 saddr 2a0e:aa07:e220::/44 accept";
      podmanScoped = !(config.virtualisation.podman.enable or false) || hasRule ''iifname "podman*" accept'';
      preservesDynamicTables = !config.networking.nftables.flushRuleset;
    }
  )
  outputs.nixosConfigurations
