{ lib
, outputs
,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (name: name)
