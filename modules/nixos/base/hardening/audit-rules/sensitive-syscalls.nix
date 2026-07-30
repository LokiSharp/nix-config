{ config, helpers, ... }:

let
  systemdExe = "${config.systemd.package}/lib/systemd/systemd";
  systemdManagedSyscalls = [
    # Traditional mount API
    "mount"
    "umount2"

    # Modern mount API
    "fsopen"
    "fsconfig"
    "fsmount"
    "fspick"
    "open_tree"
    "move_mount"
    "mount_setattr"

    # Namespace management used by system and user service managers
    "unshare"
    "setns"
  ];
in
# A per-user systemd manager inherits the login audit UID from SSH. Exclude its
  # routine service sandbox setup before applying the interactive-session rules.
[
  "-a never,exit -F arch=b64 -S ${builtins.concatStringsSep "," systemdManagedSyscalls} -F exe=${systemdExe}"
]
# Attribute direct kernel operations to interactive/login sessions while
# avoiding normal daemon activity, whose login audit UID is unset.
++ helpers.sessionSyscallRules [
  # Traditional mount API
  "mount"
  "umount2"

  # Modern mount API
  "fsopen"
  "fsconfig"
  "fsmount"
  "fspick"
  "open_tree"
  "move_mount"
  "mount_setattr"
] "mount_change"
++ helpers.sessionSyscallRules [
  "unshare"
  "setns"
] "namespace_change"
++ helpers.sessionSyscallRules [ "bpf" ] "bpf_change"
# kexec is rare and security-sensitive enough to audit for every caller. The
# compatibility ABI uses a different syscall name and has no kexec_file_load.
++ (helpers.syscallRulesFor [ "b64" ]
  [
    "kexec_load"
    "kexec_file_load"
  ]
  [ ]
  "kernel_kexec"
)
++ (helpers.syscallRulesFor [ "b32" ] [ "sys_kexec_load" ] [ ] "kernel_kexec")
