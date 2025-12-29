{
  mylib,
  lib,
  inputs,
  config,
  ...
}:
let
  configLib = mylib.withConfig config;
  ztHosts = lib.filterAttrs (_n: v: v.zerotier != null) configLib.hosts;
  ztMembers = lib.mapAttrs' (
    n: v:
    let
      i = builtins.toString v.index;
    in
    lib.nameValuePair v.zerotier {
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

    # Default routing to EDGE
    {
      target = "0.0.0.0/0";
      via = "198.18.0.1";
    }
    {
      target = "::/0";
      via = "fdbc:f9dc:67ad::1";
    }
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
        ++ (lib.optionals (v.dn42.IPv4 != "") [ "${v.dn42.IPv4}/32" ])
        ++ (lib.optionals (v.dn42.IPv6 != "") [ "${v.dn42.IPv6}/128" ])
        ++ (lib.optionals (v.loki-net.IPv4 != "") [ "${v.loki-net.IPv4}/32" ])
        ++ (lib.optionals (v.loki-net.IPv6 != "") [ "${v.loki-net.IPv6}/128" ]);
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
