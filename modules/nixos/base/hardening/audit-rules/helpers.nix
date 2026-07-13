let
  # All NixOS hosts in this repository are x86_64. Cover native and compat
  # syscalls explicitly so path rules stay complete without using slow legacy
  # watches.
  architectures = [
    "b32"
    "b64"
  ];

  syscallRulesFor =
    ruleArchitectures: syscalls: filters: key:
    map (
      arch:
      builtins.concatStringsSep " " (
        [
          "-a always,exit"
          "-F arch=${arch}"
          "-S ${builtins.concatStringsSep "," syscalls}"
        ]
        ++ filters
        ++ [ "-F key=${key}" ]
      )
    ) ruleArchitectures;
in
{
  inherit syscallRulesFor;

  pathRules =
    path: permissions: key:
    map (
      arch: "-a always,exit -F arch=${arch} -F path=${path} -F perm=${permissions} -F key=${key}"
    ) architectures;

  syscallRules = syscalls: key: syscallRulesFor architectures syscalls [ ] key;

  sessionSyscallRules =
    syscalls: key: syscallRulesFor architectures syscalls [ "-F auid!=unset" ] key;
}
