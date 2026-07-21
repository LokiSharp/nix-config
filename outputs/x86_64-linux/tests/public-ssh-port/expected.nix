{ lib
, mylib
, outputs
, ...
}:
let
  publicHostNames =
    lib.filter
      (
        name:
        let
          host = mylib.hosts.${lib.toLower name};
        in
        host.public.IPv4 != ""
      )
      (builtins.attrNames outputs.nixosConfigurations);
in
lib.genAttrs publicHostNames (_: {
  opensshListensOnConfiguredPort = true;
  nftablesEnabled = true;
  firewallAllowsConfiguredSshPort = true;
})
