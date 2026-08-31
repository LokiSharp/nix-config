_:
{
  corsLockedToPublicHost = true;
  corsNotWildcard = true;
  secretsNotInNix = true;
  allowedHostsLocked = true;
  shellToolsDisabled = true;
  schedulerEnabled = true;
  trustsForwardedHeaders = true;
  vhostProxiesLocal = true;
  vhostPreservesHost = true;
  vhostForwardsProto = true;
  vhostDropsOrigin = true;
  vhostFlushesSse = true;
  portNotGloballyOpened = true;
  portsPublishedOnLoopback = true;
  stateDirOnDataApps = true;
  envFileBindMounted = true;
  gaiConfMounted = true;
  imageIsLocal = true;
  neverPullsRegistry = true;
  dropsCapabilities = true;
  keepsSandboxSetuid = true;
  readOnlyRootfs = true;
  noNewPrivileges = true;
  containerRequiresImage = true;
  imageBuildIsOneshot = true;
  envMergeBeforeStart = true;
  healthProbeIsLive = true;
}
