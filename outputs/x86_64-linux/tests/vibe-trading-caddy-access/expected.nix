_:
{
  corsLockedToPublicHost = true;
  corsNotWildcard = true;
  secretsNotInNix = true;
  allowedHostsLocked = true;
  shellToolsDisabled = true;
  schedulerEnabled = true;
  vhostProxiesLocal = true;
  vhostPreservesHost = true;
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
