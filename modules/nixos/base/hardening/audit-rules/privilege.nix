{ config, lib, ... }:

let
  wrapperRule =
    name: key:
    lib.optional (
      builtins.hasAttr name config.security.wrappers
      && config.security.wrappers.${name}.enable
    ) "-w /run/wrappers/bin/${name} -p x -k ${key}";
in
lib.optionals config.security.sudo.enable [
  "-w /etc/sudoers -p wa -k privilege"
]
++ wrapperRule "sudo" "privilege_exec"
++ wrapperRule "sudoedit" "privilege_exec"
++ wrapperRule "su" "privilege_exec"
++ wrapperRule "newgrp" "privilege_exec"
++ wrapperRule "sg" "privilege_exec"
++ wrapperRule "newuidmap" "namespace_exec"
++ wrapperRule "newgidmap" "namespace_exec"
