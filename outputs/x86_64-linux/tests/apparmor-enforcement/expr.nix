{ lib, outputs, ... }:
let
  hostNames = builtins.attrNames outputs.nixosConfigurations;

  apparmorBeforeBpf =
    lsm:
    let
      indexed = lib.imap0 (index: name: { inherit index name; }) lsm;
      apparmor = lib.findFirst (it: it.name == "apparmor") null indexed;
      bpf = lib.findFirst (it: it.name == "bpf") null indexed;
    in
    apparmor != null && bpf != null && apparmor.index < bpf.index;
in
lib.genAttrs hostNames (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
    stage2Enabled = config.modules.base.hardening.enable && config.modules.base.hardening."stage-2".enable;
    enforceProfiles = config.modules.base.hardening."stage-2".enforceProfiles;
  in
  {
    enforceProfilesExist = lib.all (
      profile: builtins.hasAttr profile config.security.apparmor.policies
    ) enforceProfiles;

    enforceProfilesAreEnforced = lib.all (
      profile: config.security.apparmor.policies.${profile}.state == "enforce"
    ) enforceProfiles;

    apparmorPrecedesBpf = (!stage2Enabled) || apparmorBeforeBpf config.security.lsm;
  }
)
