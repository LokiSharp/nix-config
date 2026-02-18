{
  mylib,
  config,
  lib,
  ...
}:
let
  configLib = mylib.withConfig config;

  slk-net = "9f1353f914000001";
  interfaceName = "zt-slk0";

  isEnabled = configLib.this.hasTag configLib.tags.zerotier;
in
{
  services.zerotierone = {
    enable = isEnabled;
    joinNetworks = [ slk-net ];
  };

  systemd.services.zerotierone.preStart = lib.mkIf isEnabled ''
    mkdir -p /var/lib/zerotier-one
    echo "${slk-net}=${interfaceName}" > /var/lib/zerotier-one/devicemap
  '';
}
