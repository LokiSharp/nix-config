{ config
, lib
, mylib
, pkgs
, ...
}:
let
  bgpPasswordConfs =
    lib.unique (lib.filter (path: path != "") (
      lib.mapAttrsToList (_name: peer: peer.peerBgpPasswordConf) (config.services.loki-net or { })
    ));
  bgpPasswordConfRules =
    lib.concatMapStringsSep "\n"
      (
        path:
        let
          renderedPrefix = "/run/secrets/rendered/";
          renderedName = lib.removePrefix renderedPrefix path;
          rules = [
            "${path} r,"
          ] ++ lib.optionals (lib.hasPrefix renderedPrefix path) [
            "/run/secrets.d/*/rendered/${renderedName} r,"
          ];
        in
        lib.concatStringsSep "\n" rules
      )
      bgpPasswordConfs;
in
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "bird";
    enable = config.services.bird.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

      ${pkgs.bird3}/bin/bird {
        #include <abstractions/base>
        #include <abstractions/nameservice>

        capability net_admin,
        capability net_bind_service,
        capability net_raw,
        capability setgid,
        capability setuid,

        network inet,
        network inet6,
        network raw,

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.bird3}/bin/bird mr,

        # Configuration
        /etc/bird/** r,
        ${bgpPasswordConfRules}

        # Runtime
        /run/bird/** rwkl,

        # Network sysctls
        /proc/sys/net/ipv4/conf/all/forwarding r,
        /proc/sys/net/ipv6/conf/all/forwarding r,
      }
    '';
  };
}
