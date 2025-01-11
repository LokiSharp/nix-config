{ lib, ... }: rec {
  tags = lib.genAttrs [
    "dn42"
    "server"
    "client"

    "dn42-anycast-dns"

    "tailscale"
    "zerotier"
  ]
    (v: v);
}
