# CI secrets fixture

This directory deliberately contains no secrets. GitHub Actions overrides the
private `mysecrets` flake input with this fixture for evaluation and canary
build checks. Files used by the Test-NixOS canary contain only the placeholder
keys required for sops-nix manifest validation; all values are non-secret.

Never use this override for a deployment. Normal local evaluation, builds, and
deployment continue to use the locked private `nix-secrets` repository.
