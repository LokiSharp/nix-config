{ myvars
, lib
,
}:
let
  username = myvars.username;
  hosts = [
    "MacbookAir"
  ];
in
lib.genAttrs hosts (_: "/Users/${username}")
