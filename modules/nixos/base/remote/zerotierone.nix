{
  mylib,
  config,
  lib,
  ...
}:
let
  configLib = mylib.withConfig config;

  slk-net = "b1078f34eb000001";
  interfaceName = "zt-slk0";

  isEnabled = configLib.this.hasTag configLib.tags.zerotier;
in
{
  services.zerotierone = {
    enable = isEnabled;
    joinNetworks = [ slk-net ];
    localConf = {
      settings = {
        interfacePrefixBlacklist = [
          "tailscale0"
          "dummy0"
          "ens19"
          "ens20"
        ];
      };
    };
  };

  systemd.services.zerotierone.preStart = lib.mkIf isEnabled ''
    mkdir -p /var/lib/zerotier-one
    echo "${slk-net}=${interfaceName}" > /var/lib/zerotier-one/devicemap
  '';
}
