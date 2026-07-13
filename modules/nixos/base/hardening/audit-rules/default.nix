{
  config,
  lib,
  myvars,
  pkgs,
  ...
}:

let
  systemdExe = "${config.systemd.package}/lib/systemd/systemd";
  helpers = import ./helpers.nix;
in
lib.concatLists [
  [
    # systemd loads and unloads BPF programs during normal unit reloads.
    "-a never,exit -F arch=b64 -S bpf -F exe=${systemdExe}"
    "-A exclude,always -F msgtype=BPF -F exe=${systemdExe}"
  ]
  (import ./identity.nix { inherit helpers; })
  (import ./ssh.nix {
    inherit
      config
      helpers
      lib
      myvars
      ;
  })
  (import ./privilege.nix { inherit config helpers lib; })
  (import ./mount.nix { inherit config helpers lib; })
  (import ./sensitive-syscalls.nix { inherit helpers; })
  (import ./kernel.nix { inherit helpers; })
  (lib.optionals config.services.tailscale.enable [
    # Tailscale periodically syncs kernel netfilter state through iptables/nft.
    # Keep interactive/admin firewall changes auditable by only suppressing
    # daemon-originated records with an unset login audit uid.
    "-A exclude,always -F msgtype=NETFILTER_CFG -F auid=unset -F exe=${pkgs.iptables}/bin/iptables"
    "-A exclude,always -F msgtype=NETFILTER_CFG -F auid=unset -F exe=${pkgs.iptables}/bin/ip6tables"
    "-A exclude,always -F msgtype=NETFILTER_CFG -F auid=unset -F exe=${pkgs.iptables}/bin/xtables-nft-multi"
    "-A exclude,always -F msgtype=NETFILTER_CFG -F auid=unset -F exe=${pkgs.nftables}/bin/nft"
  ])
]
