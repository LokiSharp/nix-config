{ lib, outputs, ... }:

{
  hosts = lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
    smartdMatchesMetadata = true;
    smartctlExporterMatchesMetadata = true;
    requiredUnitsPresent = true;
  });

  monitoring = {
    nodeExporterTargetsComplete = true;
    smartctlTargetsComplete = true;
    smartctlAlertRulesEnabled = true;
  };
}
