_:
{
  apiEnabled = true;
  apiBindsAllInterfaces = true;
  dashboardBindsAllInterfaces = true;
  corsLockedToDashboard = true;
  corsNotWildcard = true;
  envNotClobberedByModule = true;
  envMergeActivation = true;
  dashboardUnlocksEnv = true;
  dashboardListensOnContainerNet = true;
  dashboardUnitEnabled = true;
  dashboardVhostProxiesLocal = true;
  apiVhostProxiesLocal = true;
  apiRequiresAuthorization = true;
  apiNotGloballyOpened = true;
  dashboardNotGloballyOpened = true;
  stateDirOnDataApps = true;
  noHostUsers = true;
  containerUsesBridge = true;
  entrypointIsInContainer = true;
  portsPublishedOnLoopback = true;
  tokenAnalyticsEnabled = true;
  sqliteNotNixpkgsVulnerable = true;
  sqliteUsesUnstable = true;
}
