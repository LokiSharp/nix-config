{ lib, ... }: rec {
  tags = lib.genAttrs [
    "dn42"
    "server"
    "client"

    "tailscale"
    "zerotier"
  ]
    (v: v);
}
