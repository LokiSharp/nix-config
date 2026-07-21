# CI secrets fixture

This directory deliberately contains no secrets. GitHub Actions overrides the
private `mysecrets` flake input with this fixture for evaluation-only checks.
The files only need to exist because sops-nix hashes their paths while
evaluating NixOS and nix-darwin configurations.

Never use this override for a build or deployment. Normal local evaluation and
deployment continue to use the locked private `nix-secrets` repository.
