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
      unitExists =
        unit:
        if lib.hasSuffix ".timer" unit then
          builtins.hasAttr (lib.removeSuffix ".timer" unit) config.systemd.timers
        else if lib.hasSuffix ".service" unit then
          builtins.hasAttr (lib.removeSuffix ".service" unit) config.systemd.services
        else
          builtins.hasAttr unit config.systemd.services;
    in
    {
      requiredUnitsExist = lib.all unitExists healthChecks.requiredUnits;
      requiredUnitsUnique = lib.length healthChecks.requiredUnits == lib.length (lib.unique healthChecks.requiredUnits);
      probesHaveRequiredUnits = lib.all
        (
          unit: builtins.elem unit healthChecks.requiredUnits
        )
        probeUnits;
    }
  )
  outputs.nixosConfigurations
