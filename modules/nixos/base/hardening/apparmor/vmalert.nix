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

          # Allow execution of itself
          ${pkgs.victoriametrics}/bin/vmalert mr,
        }
      '';
    };
  };
}
