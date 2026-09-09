{ lib, mylib, ... }:
let
  services = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/oci-containers/homepage/config/services.yaml"
  );
in
{
  listsHermesDashboard =
    lib.hasInfix "href: \"https://hermes.slk.moe/\"" services
    && lib.hasInfix "Hermes Agent dashboard" services;
  doesNotProbeAuthenticatedHermesUi = !(lib.hasInfix "siteMonitor: \"https://hermes.slk.moe" services);
}
