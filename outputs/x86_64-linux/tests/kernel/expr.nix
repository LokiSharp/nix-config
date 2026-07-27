{ lib
, outputs
,
}:
lib.genAttrs
  (builtins.attrNames outputs.nixosConfigurations)
  (
    name:
    let
      config = outputs.nixosConfigurations.${name}.config;
      kernel = config.boot.kernelPackages.kernel;
      kernelParams = config.boot.kernelParams;
      sysctl = config.boot.kernel.sysctl;
    in
    {
      architectureSupported = kernel.system == "x86_64-linux";
      minimumVersionSupported = lib.versionAtLeast kernel.version "6.12";
      requiredLsmsEnabled = builtins.elem "lsm=landlock,yama,apparmor,bpf" kernelParams;
      apparmorEnabled = builtins.elem "apparmor=1" kernelParams;
      kernelSymbolsRestricted =
        sysctl."kernel.kptr_restrict" == 2 && sysctl."kernel.dmesg_restrict" == 1;
      aslrEnabled = sysctl."kernel.randomize_va_space" == 2;
      panicOnOopsEnabled = sysctl."kernel.panic_on_oops" == 1;
      sourceRoutingDisabled =
        sysctl."net.ipv4.conf.all.accept_source_route" == 0
        && sysctl."net.ipv4.conf.default.accept_source_route" == 0
        && sysctl."net.ipv6.conf.all.accept_source_route" == 0
        && sysctl."net.ipv6.conf.default.accept_source_route" == 0;
      redirectsDisabled =
        sysctl."net.ipv4.conf.all.accept_redirects" == 0
        && sysctl."net.ipv4.conf.default.accept_redirects" == 0
        && sysctl."net.ipv4.conf.all.secure_redirects" == 0
        && sysctl."net.ipv4.conf.default.secure_redirects" == 0
        && sysctl."net.ipv4.conf.all.send_redirects" == 0
        && sysctl."net.ipv4.conf.default.send_redirects" == 0
        && sysctl."net.ipv6.conf.all.accept_redirects" == 0
        && sysctl."net.ipv6.conf.default.accept_redirects" == 0;
      broadcastIcmpIgnored = sysctl."net.ipv4.icmp_echo_ignore_broadcasts" == 1;
    }
  )
