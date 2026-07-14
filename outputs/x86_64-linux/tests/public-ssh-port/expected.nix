{
  lib,
  mylib,
  outputs,
  ...
}:
let
  publicHostNames =
    lib.filter (
      name:
      let
        host = mylib.hosts.${lib.toLower name};
      in
      host.public.IPv4 != ""
    ) (builtins.attrNames outputs.nixosConfigurations);
in
lib.genAttrs publicHostNames (_: {
  opensshListensOnPort22 = true;
  nftablesEnabled = true;
  firewallAllowsSshPort22 = true;
})
