{ config, lib, myvars, ... }:

let
  userAuthorizedKeys = [
    "root"
    myvars.username
  ];
in
lib.optionals config.services.openssh.enable (
  (map (user: "-w /etc/ssh/authorized_keys.d/${user} -p wa -k ssh_auth") userAuthorizedKeys)
  ++ [
    "-w /etc/ssh/sshd_config -p wa -k ssh_config"
  ]
  ++ (map (key: "-w ${key.path} -p wa -k ssh_hostkey") config.services.openssh.hostKeys)
)
