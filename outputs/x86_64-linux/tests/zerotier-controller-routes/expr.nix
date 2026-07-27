{ lib, outputs, ... }:

let
  routes =
    outputs.nixosConfigurations."OVH-CA-EAST-BHS".config.services.zerotierone.controller.networks."000001".routes;
  hasRoute =
    target: via:
    lib.any
      (
        route:
        route.target == target
        && route.via == via
      )
      routes;
  hasTarget = target: lib.any (route: route.target == target) routes;
in
{
  vmSlkPrefixPresent = hasRoute "fdbc:f9dc:67ad:11::/64" "fdbc:f9dc:67ad::11";
  vmDisabledDn42Absent = !hasTarget "fd6a:11d4:cacb:11::1/128";
  vmDisabledLokiNetAbsent = !hasTarget "2a0e:aa07:e220:11::1/128";
  testDn42IPv4Present = hasRoute "172.20.190.10/32" "198.18.0.10";
  testDn42IPv6Present = hasRoute "fd6a:11d4:cacb::10/128" "fdbc:f9dc:67ad::10";
  testLokiNetIPv6Present = hasRoute "2a0e:aa07:e220:10::1/128" "fdbc:f9dc:67ad::10";
}
