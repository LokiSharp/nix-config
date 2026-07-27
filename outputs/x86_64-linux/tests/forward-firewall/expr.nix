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
      takeUntilChainEnd =
        lines:
        if lines == [ ] || lib.trim (lib.head lines) == "}" then
          [ ]
        else
          [ (lib.head lines) ] ++ takeUntilChainEnd (lib.tail lines);
      forwardSections = lib.splitString "chain forward {" ruleset;
      forwardLines =
        if lib.length forwardSections == 2 then
          lib.filter (
            line: line != "" && !lib.hasPrefix "#" line
          ) (map lib.trim (takeUntilChainEnd (lib.splitString "\n" (lib.last forwardSections))))
        else
          [ ];
    in
    {
      dropsInvalidTraffic = hasRule "ct state invalid drop";
      allowsEstablishedTraffic = hasRule "ct state { established, related } accept";
      terminalDefaultDrop = forwardLines != [ ] && lib.last forwardLines == "counter drop";
      noUnconditionalAccept = !(builtins.elem "accept" forwardLines);
      zerotierScoped = !host.features.zerotier.enable || hasRule ''iifname "zt-slk0" accept'';
      dn42Scoped = !host.networks.dn42.enable || hasRule ''iifname "dn42-*" accept'';
      tailscaleScoped = !host.features.tailscale.enable || hasRule ''iifname "tailscale0" accept'';
      lokiNetScoped = !host.networks.loki-net.enable || hasRule "ip6 saddr 2a0e:aa07:e220::/44 accept";
      podmanScoped = !(config.virtualisation.podman.enable or false) || hasRule ''iifname "podman*" accept'';
      preservesDynamicTables = !config.networking.nftables.flushRuleset;
    }
  )
  outputs.nixosConfigurations
