# Audit Rule Layout

Keep rules grouped by purpose and return a flat list of `auditctl` rule
strings from each module.

- Use `helpers.pathRules` for file and executable watches. It emits explicit
  `b32` and `b64` path rules and avoids the slower legacy `-w` syntax.
- Use `helpers.syscallRules` for syscalls that must be covered by both native
  and compatibility ABIs.
- Keep keys stable because operational searches depend on them, for example
  `ausearch -k identity` and `ausearch -k privilege_exec`.
- Add exclusions only for a known high-volume daemon and keep interactive
  administrator activity auditable.
- Paths below `/run/wrappers/bin` require `audit-rules-local.service` to start
  after `suid-sgid-wrappers.service`.
