{ pkgs
, mylib
, myvars
, disko
, ...
}:
let
  hostName = "VM-Kubevirt-Node-3"; # Define your hostname.

  coreModule = mylib.genKubeVirtHostModule {
    inherit pkgs hostName;
    inherit (myvars) networking;
  };
  k3sModule = mylib.genK3sServerModule {
    inherit pkgs;
    kubeconfigFile = "/home/${myvars.username}/.kube/config";
    tokenFile = "/run/mount/nixos_k3s/kubevirt-k3s-token";
    # use my own domain & kube-vip's virtual IP for the API server
    # so that the API server can always be accessed even if some nodes are down
    masterHost = "kubevirt-cluster-1.slk.moe";
    kubeletExtraArgs = [
      "--cpu-manager-policy=static"
      # https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/
      # we have to reserve some resources for for system daemons running as pods or system services
      # when cpu-manager's static policy is enabled
      # the memory we reserved here is also for the kernel, since kernel's memory is not accounted in pods
      "--system-reserved=cpu=0.5,memory=128Mi,ephemeral-storage=1Gi"
    ];
    nodeLabels = [
      "node-purpose=kubevirt"
    ];
    # kubevirt works well with k3s's flannel,
    # but has issues with cilium(failed to configure vmi network: setup failed, err: pod link (pod6b4853bd4f2) is missing).
    # so we should not disable flannel here.
    disableFlannel = false;
  };
in
{
  imports =
    (mylib.scanPaths ./.)
    ++ [
      disko.nixosModules.default
      ../disko-config/kubevirt-disko-fs.nix
      ../vm-kubevirt-node-1/hardware-configuration.nix
      ../vm-kubevirt-node-1/impermanence.nix
      coreModule
      k3sModule
    ];

  boot.kernelParams = [
    # disable transparent hugepage(allocate hugepages dynamically)
    "transparent_hugepage=never"

    # https://kubevirt.io/user-guide/compute/hugepages/
    #
    # pre-allocate hugepages manually(for kubevirt guest vms)
    # NOTE: the hugepages allocated here can not be used for other purposes!
    # so we should left some memory for the host OS and other vms that don't use hugepages
    "hugepagesz=1G"
    "hugepages=6"
  ];
}
