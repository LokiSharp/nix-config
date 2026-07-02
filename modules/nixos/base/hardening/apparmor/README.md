# AppArmor Policy Layout

Profiles in this directory use `mylib.apparmor.mkPolicy` and should keep the
profile body grouped in this order:

1. AppArmor includes and ABI declarations.
2. Linux capabilities.
3. Network and ptrace rules.
4. Nix store reads and executable transitions.
5. Service configuration, generated files, and secrets.
6. Persistent state, application data, logs, and runtime sockets.
7. Devices and IPC files.
8. `/proc` and `/sys` runtime introspection.

Keep profiles in `complain` while collecting audit logs, then set
`state = "enforce";` per service after the observed workload is covered.
