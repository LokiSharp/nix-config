{ outputs, ... }:
{
  unfilteredApplyDisabled = !outputs.colmenaMeta.allowApplyAll;
}
