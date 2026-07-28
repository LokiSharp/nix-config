{ myvars
, lib
,
}:
let
  inherit (myvars) username;
  hosts = [
    "VM-NixOS"
  ];
in
lib.genAttrs hosts (_: "/home/${username}")
