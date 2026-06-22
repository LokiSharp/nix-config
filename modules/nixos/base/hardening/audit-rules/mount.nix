{ config, lib, ... }:

let
  wrapperRule =
    name:
    lib.optional (
      builtins.hasAttr name config.security.wrappers
      && config.security.wrappers.${name}.enable
    ) "-w /run/wrappers/bin/${name} -p x -k mount_exec";
in
wrapperRule "mount"
++ wrapperRule "umount"
++ wrapperRule "fusermount"
++ wrapperRule "fusermount3"
