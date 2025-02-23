{ lib }:
rec {
  mainGateway = "192.168.0.1";
  defaultGateway = "192.168.0.1";
  nameservers = [
    "192.168.0.1"
  ];
  prefixLength = 24;

  hostsAddr = {
    DESKTOP-NixOS = {
      iface = "enp0s31f6";
      ipv4 = "192.168.0.10";
    };
    VM-NixOS = {
      iface = "enp6s18";
      ipv4 = "192.168.0.11";
    };

    K3S-Test-1-Master-1 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.201";
    };
    K3S-Test-1-Master-2 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.202";
    };
    K3S-Test-1-Master-3 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.203";
    };

    K3S-Prod-1-Master-1 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.211";
    };
    K3S-Prod-1-Master-2 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.212";
    };
    K3S-Prod-1-Master-3 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.213";
    };
    K3S-Prod-1-Worker-1 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.221";
    };
    K3S-Prod-1-Worker-2 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.222";
    };
    K3S-Prod-1-Worker-3 = {
      iface = "enp6s18";
      ipv4 = "192.168.0.223";
    };

    Server-NixOS = {
      iface = "enp6s18";
      ipv4 = "192.168.0.12";
    };
    Test-NixOS = {
      iface = "enp6s18";
      ipv4 = "192.168.0.13";
    };
  };

  hostsInterface = lib.attrsets.mapAttrs (key: val: {
    interfaces."${val.iface}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          inherit prefixLength;
          address = val.ipv4;
        }
      ];
    };
  }) hostsAddr;

  ssh = {
    # define the host alias for remote builders
    # this config will be written to /etc/ssh/ssh_config
    # ''
    #   Host <name>
    #     HostName <ipAddr>
    #     Port 22
    #   ...
    # '';
    extraConfig = lib.attrsets.foldlAttrs (
      acc: host: val:
      acc
      + ''
        Host ${host}
          HostName ${val.ipv4}
          Port 22
      ''
    ) "" hostsAddr;

    # define the host key for remote builders so that nix can verify all the remote builders
    # this config will be written to /etc/ssh/ssh_known_hosts
    knownHosts =
      # Update only the values of the given attribute set.
      #
      #   mapAttrs
      #   (name: value: ("bar-" + value))
      #   { x = "a"; y = "b"; }
      #     => { x = "bar-a"; y = "bar-b"; }
      lib.attrsets.mapAttrs (host: value: {
        hostNames = [
          host
          hostsAddr.${host}.ipv4
        ];
        publicKey = value.publicKey;
      }) { };
  };
}
