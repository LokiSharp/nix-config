{ lib
, outputs
,
}:
let
  hostsNames = builtins.attrNames outputs.nixosConfigurations;
  expected = lib.genAttrs hostsNames (_: {
    architectureSupported = true;
    minimumVersionSupported = true;
    requiredLsmsEnabled = true;
    apparmorEnabled = true;
    kernelSymbolsRestricted = true;
    aslrEnabled = true;
    panicOnOopsEnabled = true;
    sourceRoutingDisabled = true;
    redirectsDisabled = true;
    broadcastIcmpIgnored = true;
  });
in
expected
