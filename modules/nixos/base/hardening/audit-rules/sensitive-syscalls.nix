{ helpers, ... }:

# Attribute direct kernel operations to interactive/login sessions while
# avoiding normal systemd and daemon activity, whose login audit UID is unset.
helpers.sessionSyscallRules [
  "mount"
  "umount2"
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
