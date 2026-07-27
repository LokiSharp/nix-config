{ ... }:
{
  deploymentTagsUnique = true;
  legacyDeploymentTagsAbsent = true;

  indexValidation = {
    missingIndexRejected = true;
    outOfRangeRejected = true;
    mismatchedAddressRejected = true;
  };

  globalValidation = {
    validMetadataAccepted = true;
    duplicateIndexRejected = true;
    duplicateZerotierNodeIdRejected = true;
    duplicateDn42IPv4Rejected = true;
    duplicateDn42IPv6Rejected = true;
    duplicateLokiNetIPv4Rejected = true;
    duplicateLokiNetIPv6Rejected = true;
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
