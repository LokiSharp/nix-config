{
  config,
  helpers,
  lib,
  myvars,
  ...
}:

let
  userAuthorizedKeys = [
    "root"
    myvars.username
  ];
in
lib.optionals config.services.openssh.enable (
  (builtins.concatMap (
    user: helpers.pathRules "/etc/ssh/authorized_keys.d/${user}" "wa" "ssh_auth"
  ) userAuthorizedKeys)
  ++ helpers.pathRules "/etc/ssh/sshd_config" "wa" "ssh_config"
  ++ (builtins.concatMap (
    key: helpers.pathRules key.path "wa" "ssh_hostkey"
  ) config.services.openssh.hostKeys)
)
