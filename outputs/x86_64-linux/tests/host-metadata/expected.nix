{ ... }:
{
  allHostsValid = true;
  deploymentTagsUnique = true;
  legacyDeploymentTagsAbsent = true;

  indexValidation = {
    allInRange = true;
    allSlkAddressesDerived = true;
    missingIndexRejected = true;
    outOfRangeRejected = true;
    mismatchedAddressRejected = true;
  };

  globalUniqueness = {
    indexes = true;
    zerotierNodeIds = true;
    slkNetIPv4 = true;
    slkNetIPv6 = true;
    dn42IPv4 = true;
    dn42IPv6 = true;
    lokiNetIPv4 = true;
    lokiNetIPv6 = true;
  };

  vultrMetadata = {
    role = "server";
    kind = "vps";
    firewall = true;
    zerotierNodeId = "9e786cf795";
    dn42 = true;
    lokiNetRole = "edge";
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
