{ ... }:
{
  allHostsValid = true;
  deploymentTagsUnique = true;

  vultrMetadata = {
    role = "server";
    kind = "vps";
    firewall = true;
    zerotierNodeId = "9e786cf795";
    dn42 = true;
    lokiNetRole = "edge";
  };

  compatibilityTags = {
    server = true;
    lokiNetEdge = true;
  };

  namespacedDeploymentTags = {
    role = true;
    kind = true;
    network = true;
    topology = true;
  };

  freeFormDeploymentTags = {
    server = true;
    vm = true;
  };
}
