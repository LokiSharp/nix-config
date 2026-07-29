# CI secrets fixture

This directory deliberately contains no secrets. GitHub Actions overrides the
private `mysecrets` flake input with this fixture for evaluation and canary
build checks. The fixture mirrors every key declared by the NixOS and nix-darwin
configurations so CI can validate the complete sops-nix schema and build every
NixOS secret manifest. All values are non-secret placeholders.

Never use this override for a deployment. Normal local evaluation, builds, and
deployment continue to use the locked private `nix-secrets` repository.
