{ helpers, ... }:

builtins.concatMap (path: helpers.pathRules path "wa" "identity") [
  "/etc/passwd"
  "/etc/group"
  "/etc/shadow"
]
