{ lib
, outputs
, ...
}:

lib.mapAttrs
  (
    _name: system:
    let
      inherit (system) config;
      healthChecks = config.deployment.healthChecks;
      probeUnits = builtins.attrNames healthChecks.httpProbes;
    in
    {
      requiredUnitsExist = lib.all
        (
          unit: builtins.hasAttr unit config.systemd.services
        )
        healthChecks.requiredUnits;
      requiredUnitsUnique = lib.length healthChecks.requiredUnits == lib.length (lib.unique healthChecks.requiredUnits);
      probesHaveRequiredUnits = lib.all
        (
          unit: builtins.elem unit healthChecks.requiredUnits
        )
        probeUnits;
    }
  )
  outputs.nixosConfigurations
