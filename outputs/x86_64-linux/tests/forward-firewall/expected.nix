{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  dropsInvalidTraffic = true;
  allowsEstablishedTraffic = true;
  terminalDefaultDrop = true;
  noUnconditionalAccept = true;
  zerotierScoped = true;
  dn42Scoped = true;
  tailscaleScoped = true;
  lokiNetScoped = true;
  podmanScoped = true;
  preservesDynamicTables = true;
})
