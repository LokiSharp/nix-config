{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.base.hardening;
  vmalertInstances = config.services.vmalert.instances or { };
in
{
  config = mkIf (cfg.enable && cfg."stage-2".enable && (vmalertInstances != { })) {
    security.apparmor.policies.vmalert = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.victoriametrics}/bin/vmalert {
          #include <abstractions/base>
          #include <abstractions/nameservice>
          #include <abstractions/ssl_certs>

          capability dac_override,
          capability sys_resource,

          network inet,
          network inet6,
          network tcp,
          network udp,

          # Allow reading from nix store for executables and rules
          /nix/store/** r,
          /nix/store/** m,

          # Local rule files
          /etc/vmalert/ r,
          /etc/vmalert/** r,

          # Runtime / Go / system introspection
          /dev/tty r,

          /proc/sys/net/core/somaxconn r,

          /proc/self/cgroup r,
          /proc/self/mountinfo r,

          /proc/[0-9]*/cgroup r,
          /proc/[0-9]*/mountinfo r,

          # cgroup limits / pressure
          /sys/fs/cgroup/system.slice/vmalert.service/cpu.max r,
          /sys/fs/cgroup/system.slice/vmalert.service/cpu.pressure r,
          /sys/fs/cgroup/system.slice/vmalert.service/io.pressure r,
          /sys/fs/cgroup/system.slice/vmalert.service/memory.pressure r,

          /sys/fs/cgroup/system.slice/cpu.max r,
          /sys/fs/cgroup/system.slice/memory.max r,

          # Allow execution of itself
          ${pkgs.victoriametrics}/bin/vmalert mr,
        }
      '';
    };
  };
}
