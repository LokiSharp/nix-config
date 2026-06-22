{ config, lib, myvars, ... }:

lib.concatLists [
  (import ./identity.nix)
  (import ./ssh.nix { inherit config lib myvars; })
  (import ./privilege.nix { inherit config lib; })
  (import ./mount.nix { inherit config lib; })
  (import ./kernel.nix)
]
