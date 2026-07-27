{
  mylib,
  lib,
  inputs,
  config,
  ...
}:
let
  configLib = mylib.withConfig config;
  ztHosts = lib.filterAttrs (_n: v: v.features.zerotier.nodeId != null) configLib.hosts;
  ztMembers = lib.mapAttrs' (
    n: v:
    let
      i = builtins.toString v.index;
    in
    lib.nameValuePair v.features.zerotier.nodeId {
      name = n;
      ipAssignments = [
        "198.18.0.${i}"
        "fdbc:f9dc:67ad::${i}"
      ];
      noAutoAssignIps = true;
    }
  ) ztHosts;
  ztRoutes = [
    { target = "198.18.0.0/24"; }
    { target = "fdbc:f9dc:67ad::/64"; }
  ]
  ++ (lib.flatten (
    lib.mapAttrsToList (
      _n: v:
      let
        i = builtins.toString v.index;
        routes = [
          "198.18.${i}.0/24"
          "198.19.${i}.0/24"
          "fdbc:f9dc:67ad:${i}::/64"
        ]
        ++ (lib.optionals (v.networks.dn42.enable && v.networks.dn42.IPv4 != "") [ "${v.networks.dn42.IPv4}/32" ])
        ++ (lib.optionals (v.networks.dn42.enable && v.networks.dn42.IPv6 != "") [ "${v.networks.dn42.IPv6}/128" ])
        ++ (lib.optionals (v.networks.loki-net.enable && v.networks.loki-net.IPv4 != "") [ "${v.networks.loki-net.IPv4}/32" ])
        ++ (lib.optionals (v.networks.loki-net.enable && v.networks.loki-net.IPv6 != "") [ "${v.networks.loki-net.IPv6}/128" ]);
      in
      builtins.map (r: {
        target = r;
        via = if lib.hasInfix ":" r then "fdbc:f9dc:67ad::${i}" else "198.18.0.${i}";
      }) routes
    ) ztHosts
  ));
in
{
  imports = [ ./upstreamable.nix ];

  services.zerotierone.controller = {
    enable = true;
    port = 9994;
    networks = {
      "000001" = {
        name = "SLK-NET";
        multicastLimit = 256;
        routes = ztRoutes;
        members = ztMembers;
      };
    };
  };
}
