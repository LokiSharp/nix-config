{ myvars
, lib
,
}:
let
  inherit (myvars) username;
  hosts = [
    "MacbookAir"
  ];
in
lib.genAttrs hosts (_: "/Users/${username}")
