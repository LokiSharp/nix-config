{ lib, myvars, outputs, ... }:

let
  expectedFlag =
    "--collector.filesystem.mount-points-exclude=^/(dev|proc|run/credentials/.+|run/user/.+|sys|var/lib/docker/.+|var/lib/containers/storage/.+|home/${myvars.username}/.+)($|/)";
in
lib.mapAttrs
  (
    _name: system:
    {
      inaccessibleMountsExcluded =
        builtins.elem expectedFlag system.config.services.prometheus.exporters.node.extraFlags;
    }
  )
  outputs.nixosConfigurations
