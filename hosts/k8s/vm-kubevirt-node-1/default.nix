{ config
, pkgs
, mylib
, myvars
, disko
, ...
}:
let
  hostName = "VM-Kubevirt-Node-1"; # Define your hostname.

  coreModule = mylib.genKubeVirtHostModule {
    inherit pkgs hostName;
    inherit (myvars) networking;
  };
  k3sModule = mylib.genK3sServerModule {
    inherit pkgs;
    kubeconfigFile = "/home/${myvars.username}/.kube/config";
    tokenFile = config.age.secrets."kubevirt-k3s-token".path;
    # the first node in the cluster should be the one to initialize the cluster
    clusterInit = true;
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
      ./hardware-configuration.nix
      ./impermanence.nix
      coreModule
      k3sModule
    ];
}
