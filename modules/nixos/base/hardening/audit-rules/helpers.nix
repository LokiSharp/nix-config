let
  # All NixOS hosts in this repository are x86_64. Cover native and compat
  # syscalls explicitly so path rules stay complete without using slow legacy
  # watches.
  architectures = [
    "b32"
    "b64"
  ];
in
{
  pathRules =
    path: permissions: key:
    map (
      arch: "-a always,exit -F arch=${arch} -F path=${path} -F perm=${permissions} -F key=${key}"
    ) architectures;

  syscallRules =
    syscalls: key:
    map (
      arch: "-a always,exit -F arch=${arch} -S ${builtins.concatStringsSep "," syscalls} -F key=${key}"
    ) architectures;
}
