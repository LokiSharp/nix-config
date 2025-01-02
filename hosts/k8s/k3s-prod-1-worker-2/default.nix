{ config
, pkgs
, myvars
, mylib
, disko
, ...
}:
let
  hostName = "K3S-Prod-1-Worker-2"; # Define your hostname.

  coreModule = mylib.genKubeVirtGuestModule {
    inherit pkgs hostName;
    inherit (myvars) networking;
  };
  k3sModule = mylib.genK3sAgentModule {
    inherit pkgs;
    tokenFile = config.age.secrets."k3s-prod-1-token".path;
    # use my own domain & kube-vip's virtual IP for the API server
    # so that the API server can always be accessed even if some nodes are down
    masterHost = "prod-cluster-1.slk.moe";
    # the first node in the cluster should be the one to initialize the cluster
    disableFlannel = false;
  };
in
{
  imports = [
    disko.nixosModules.default
    ../disko-config/k3s-node-disko-fs.nix
    ../impermanence.nix
    coreModule
    k3sModule
  ];
}
