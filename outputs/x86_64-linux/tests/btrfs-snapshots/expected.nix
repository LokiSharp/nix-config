{ lib
, outputs
, ...
}:

{
  hosts = lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
    instanceMatchesFilesystems = true;
    sourcesMatchFilesystems = true;
    destinationsMatchFilesystems = true;
    retentionPolicyConfigured = true;
    mountDependenciesComplete = true;
    timerMonitored = true;
    successSummarySuppressed = true;
    metricsExported = true;
  });

  ovhAppsSnapshotPair = true;
  serverAppsSnapshotPair = true;
  ovhReservedDataMounts = true;
}
