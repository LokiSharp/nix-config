{ lib, ... }: rec {
  tags = lib.genAttrs [
    "dn42"
    "server"
    "client"

    "firewall"

    "dn42-anycast-dns"

    "tailscale"
    "zerotier"
  ]
    (v: v);
}
