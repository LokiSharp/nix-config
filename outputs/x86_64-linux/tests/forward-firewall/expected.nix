{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  dropsInvalidTraffic = true;
  allowsEstablishedTraffic = true;
  defaultDeny = true;
  noUnconditionalForwardAccept = true;
  zerotierScoped = true;
  dn42Scoped = true;
  tailscaleScoped = true;
  lokiNetScoped = true;
  podmanScoped = true;
})
