{ config
, helpers
, lib
, ...
}:

let
  wrapperRule =
    name: key:
    lib.optionals
      (
        builtins.hasAttr name config.security.wrappers && config.security.wrappers.${name}.enable
      )
      (helpers.pathRules "/run/wrappers/bin/${name}" "x" key);
in
lib.optionals config.security.sudo.enable (helpers.pathRules "/etc/sudoers" "wa" "privilege")
++ wrapperRule "sudo" "privilege_exec"
++ wrapperRule "sudoedit" "privilege_exec"
++ wrapperRule "su" "privilege_exec"
++ wrapperRule "newgrp" "privilege_exec"
++ wrapperRule "sg" "privilege_exec"
++ wrapperRule "newuidmap" "namespace_exec"
++ wrapperRule "newgidmap" "namespace_exec"
