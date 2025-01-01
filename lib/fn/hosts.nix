{ lib
, hostsBase
, ...
}:
lib.genAttrs (builtins.attrNames (builtins.readDir hostsBase)) (
  n:
  (lib.evalModules {
    modules = [
      ../host-options.nix
      (hostsBase + "/${n}/host.nix")
    ];
  }).config
)
