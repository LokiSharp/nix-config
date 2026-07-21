{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  requiredUnitsExist = true;
  requiredUnitsUnique = true;
  probesHaveRequiredUnits = true;
})
