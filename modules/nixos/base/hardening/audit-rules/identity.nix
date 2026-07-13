{
  config,
  helpers,
  lib,
  ...
}:

let
  users = builtins.attrValues config.users.users;
  hasSubUid = lib.any (user: user.autoSubUidGidRange || user.subUidRanges != [ ]) users;
  hasSubGid = lib.any (user: user.autoSubUidGidRange || user.subGidRanges != [ ]) users;
  identityPaths = [
    "/etc/passwd"
    "/etc/group"
    "/etc/shadow"
  ]
  ++ lib.optionals hasSubUid [ "/etc/subuid" ]
  ++ lib.optionals hasSubGid [ "/etc/subgid" ];
in
builtins.concatMap (path: helpers.pathRules path "wa" "identity") identityPaths
