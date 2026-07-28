{ config
, helpers
, lib
, ...
}:

let
  wrapperRule =
    name:
    lib.optionals
      (
        builtins.hasAttr name config.security.wrappers && config.security.wrappers.${name}.enable
      )
      (helpers.pathRules "/run/wrappers/bin/${name}" "x" "mount_exec");
in
wrapperRule "mount" ++ wrapperRule "umount" ++ wrapperRule "fusermount" ++ wrapperRule "fusermount3"
