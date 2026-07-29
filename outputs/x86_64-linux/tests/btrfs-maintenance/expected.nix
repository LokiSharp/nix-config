{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  autoScrubMatchesFilesystems = true;
  healthServiceMatchesFilesystems = true;
  healthTimerMatchesFilesystems = true;
  scrubMountPointsUnique = true;
})
