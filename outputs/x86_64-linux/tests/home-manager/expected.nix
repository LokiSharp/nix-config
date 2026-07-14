{ myvars
, lib
,
}:
let
  username = myvars.username;
  hosts = [
    "VM-NixOS"
  ];
in
lib.genAttrs hosts (_: "/home/${username}")
