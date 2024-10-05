{ myvars
, lib
,
}:
let
  username = myvars.username;
  hosts = [
    "DESKTOP-NixOS"
    "VM-NixOS"
  ];
in
lib.genAttrs hosts (_: "/home/${username}")
