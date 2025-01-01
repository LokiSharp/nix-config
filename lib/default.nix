{ config ? { }
, pkgs ? { }
, lib ? pkgs.lib
, self ? null
, hostsBase ? ../hosts
, ...
}:
let
  call =
    path:
    builtins.removeAttrs (lib.callPackageWith (pkgs // helpers) path { }) [
      "override"
      "overrideDerivation"
    ];
  helpers = rec {
    inherit
      config
      pkgs
      lib
      hostsBase
      ;
    hosts = call ./fn/hosts.nix;
    this = hosts."${lib.toLower config.networking.hostName}";

    colmenaSystem = import ./system/colmenaSystem.nix;
    nixosSystem = import ./system/nixosSystem.nix;

    attrs = import ./fn/attrs.nix { inherit lib; };

    genK3sServerModule = import ./gen-k3s/genK3sServerModule.nix;
    genK3sAgentModule = import ./gen-k3s/genK3sAgentModule.nix;
    genKubeVirtHostModule = import ./gen-k3s/genKubeVirtHostModule.nix;
    genKubeVirtGuestModule = import ./gen-k3s/genKubeVirtGuestModule.nix;

    # use path relative to the root of the project
    relativeToRoot = lib.path.append ../.;
    scanPaths = path:
      builtins.map
        (f: (path + "/${f}"))
        (builtins.attrNames
          (lib.attrsets.filterAttrs
            (
              path: _type:
                (_type == "directory") # include directories
                || (
                  (path != "default.nix") # ignore default.nix
                  && (lib.strings.hasSuffix ".nix" path) # include .nix files
                )
            )
            (builtins.readDir path)));
  };
in
helpers
