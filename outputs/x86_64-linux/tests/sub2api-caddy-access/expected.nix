_:
{
  vhostProxiesLocal = true;
  vhostPreservesHost = true;
  vhostForwardsProto = true;
  vhostFlushesSse = true;
  portNotGloballyOpened = true;
  portsPublishedOnLoopback = true;
  postgresNotPublished = true;
  redisNotPublished = true;
  stateDirOnDataApps = true;
  gaiConfMounted = true;
  envFileUsed = true;
  secretsNotInNix = true;
  runModeIsSimple = true;
  autoSetupEnabled = true;
  databaseIsInternal = true;
  redisIsInternal = true;
  imagePinnedNotLatest = true;
  appImageFromGhcr = true;
  depsUseDaocloudMirror = true;
  appDropsCapabilities = true;
  appKeepsSandboxSetuid = true;
  redisDropsCapabilities = true;
  appReadOnlyRootfs = true;
  noNewPrivileges = true;
  isolatedNetwork = true;
  waitsForHealthyDeps = true;
  prepareIsOneshot = true;
  containersRequirePrepare = true;
  healthProbeIsLive = true;
  requiredUnitsCoverStack = true;
}
