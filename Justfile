# just is a command runner, Justfile is very similar to Makefile, but simpler.

# Use nushell for shell commands
# To usage this justfile, you need to enter a shell with just & nushell installed:
# 
#   nix shell nixpkgs#just nixpkgs#nushell
set shell := ["nu", "-c"]

utils_nu := absolute_path("utils.nu")

############################################################################
#
#  Common commands(suitable for all machines)
#
############################################################################

# List all the just commands
default:
    @just --list

# Enable the version-controlled pre-commit and pre-push hooks for this clone
[group('git')]
install-hooks:
  #!/usr/bin/env bash
  set -euo pipefail
  git config --local core.hooksPath .githooks
  echo "[PASS] Git hooks enabled from .githooks"

# Run eval tests
[group('nix')]
test:
  #!/usr/bin/env bash
  set -euo pipefail

  report_stderr="$(mktemp)"
  result_stderr="$(mktemp)"
  trap 'rm -f "$report_stderr" "$result_stderr"' EXIT

  if ! nix --quiet eval .#evalTestReportText --raw --show-trace 2>"$report_stderr"; then
    cat "$report_stderr" >&2
    exit 1
  fi

  if ! result="$(nix --quiet eval .#evalTests --show-trace 2>"$result_stderr")"; then
    cat "$result_stderr" >&2
    exit 1
  fi
  if [ "$result" != "true" ]; then
    echo "Evaluation tests failed:"
    nix --quiet eval .#evalTestFailureText --raw --show-trace || true
    echo "Inspect details with:"
    echo "  nix eval .#evalTestResults --show-trace"
    exit 1
  fi

# Run post-deploy smoke checks on the current NixOS host
[linux]
[group('nix')]
smoke since="-5 minutes":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-smoke --since "{{since}}"

# Check public TCP exposure for public NixOS hosts
[linux]
[group('nix')]
public-exposure:
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  public-exposure

# Run configuration-derived health checks over all nodes or selected node names
# Usage: just deploy-health Test-NixOS Server-NixOS
[linux]
[group('deployment')]
deploy-health *hosts:
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  deployment-health {{hosts}}

# Check the flake, deploy Test-NixOS, and stop if its canary checks fail
[linux]
[group('deployment')]
deploy-test parallel="2":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  deployment-test --parallel {{parallel}}

# Check the flake, deploy and verify Test-NixOS, then deploy and verify every other node
[linux]
[group('deployment')]
deploy-all parallel="2":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  deployment-rollout --parallel {{parallel}}

# Update all the flake inputs
[group('nix')]
up:
  nix flake update

# Update specific input
# Usage: just upp nixpkgs
[group('nix')]
upp input:
  nix flake update {{input}}

# List all generations of the system profile
[group('nix')]
history:
  nix profile history --profile /nix/var/nix/profiles/system

# Open a nix shell with the flake
[group('nix')]
repl:
  nix repl -f flake:nixpkgs

# remove all generations older than 7 days
# on darwin, you may need to switch to root user to run this command
[group('nix')]
clean:
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

# Garbage collect all unused nix store entries
[group('nix')]
gc:
  # garbage collect all unused nix store entries(system-wide)
  sudo nix-collect-garbage --delete-older-than 7d
  # garbage collect all unused nix store entries(for the user - home-manager)
  # https://github.com/NixOS/nix/issues/8508
  nix-collect-garbage --delete-older-than 7d

# Enter a shell session which has all the necessary tools for this flake
[linux]
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim nixpkgs#colmena

[group('nix')]
fmt:
  # format the nix files in this repo
  nix fmt

# Show all the auto gc roots in the nix store
[group('nix')]
gcroot:
  ls -al /nix/var/nix/gcroots/auto/

# Verify all the store entries
# Nix Store can contains corrupted entries if the nix store object has been modified unexpectedly.
# This command will verify all the store entries,
# and we need to fix the corrupted entries manually via `sudo nix store delete <store-path-1> <store-path-2> ...`
[group('nix')]
verify-store:
  nix store verify --all

# Repair Nix Store Objects
[group('nix')]
repair-store *paths:
  nix store repair {{paths}}

############################################################################
#
#  Darwin related commands, harmonica is my macbook pro's hostname
#
############################################################################

[macos]
[group('desktop')]
darwin-set-proxy:
  sudo python3 scripts/darwin_set_proxy.py
  sleep 1sec

[macos]
[group('desktop')]
darwin-rollback:
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  darwin-rollback

# Update Homebrew formulae and casks manually
[macos]
[group('desktop')]
brew-upgrade:
  #!/usr/bin/env bash
  set -euo pipefail

  brew_without_git_mirror=(
    env
    -u HOMEBREW_BREW_GIT_REMOTE
    -u HOMEBREW_CORE_GIT_REMOTE
    brew
  )

  "${brew_without_git_mirror[@]}" update
  HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1 "${brew_without_git_mirror[@]}" upgrade --formula
  "${brew_without_git_mirror[@]}" upgrade --cask
  "${brew_without_git_mirror[@]}" cleanup

# Clean Homebrew caches and stale downloads
[macos]
[group('desktop')]
brew-cleanup:
  brew cleanup

# Uninstall and zap specific Homebrew casks
[macos]
[group('desktop')]
brew-zap *casks:
  brew uninstall --cask --zap {{casks}}

# Deploy to MacbookAir(macOS host)
[macos]
[group('desktop')]
MacbookAir mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  darwin-build "MacbookAir" {{mode}};
  darwin-switch "MacbookAir" {{mode}}

# Reset launchpad to force it to reindex Applications
[macos]
[group('desktop')]
reset-launchpad:
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock

############################################################################
#
# Commands for other Virtual Machines
#
############################################################################

[linux]
[group('homelab')]
VM-NixOS:
  colmena apply --on '@VM-NixOS' --verbose --show-trace

[linux]
[group('homelab')]
VM-NixOS-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch VM-NixOS {{mode}}

[linux]
[group('homelab')]
Server-NixOS:
  colmena apply --on '@Server-NixOS' --verbose --show-trace

[linux]
[group('homelab')]
Server-NixOS-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch Server-NixOS {{mode}}

[linux]
[group('homelab')]
Test-NixOS:
  colmena apply --on '@Test-NixOS' --verbose --show-trace

[linux]
[group('homelab')]
Test-NixOS-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch Test-NixOS {{mode}}

############################################################################
#
# Commands for Virtual Private Server
#
############################################################################

[linux]
[group('vps')]
NodeSet-DN42:
  colmena apply --on '@net:dn42' --verbose --show-trace

[linux]
[group('vps')]
NodeSet-LOKI-NET:
  colmena apply --on '@net:loki-net' --verbose --show-trace

[linux]
[group('vps')]
RackNerd-US-NY:
  colmena apply --on '@RackNerd-US-NY' --verbose --show-trace

[linux]
[group('vps')]
RackNerd-US-NY-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch RackNerd-US-NY {{mode}}

[linux]
[group('vps')]
RackNerd-US-SJ:
  colmena apply --on '@RackNerd-US-SJ' --verbose --show-trace

[linux]
[group('vps')]
RackNerd-US-SJ-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch RackNerd-US-SJ {{mode}}

[linux]
[group('vps')]
Vultr-JP:
  colmena apply --on '@Vultr-JP' --verbose --show-trace

[linux]
[group('vps')]
Vultr-JP-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch Vultr-JP {{mode}}

[linux]
[group('vps')]
Lycheen-US-SLC:
  colmena apply --on '@Lycheen-US-SLC' --verbose --show-trace

[linux]
[group('vps')]
Lycheen-US-SLC-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch Lycheen-US-SLC {{mode}}

[linux]
[group('vps')]
MoeDove-TPE:
  colmena apply --on '@MoeDove-TPE' --verbose --show-trace

[linux]
[group('vps')]
MoeDove-TPE-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch MoeDove-TPE {{mode}}
  
[linux]
[group('vps')]
OVH-CA-EAST-BHS:
  colmena apply --on '@OVH-CA-EAST-BHS' --verbose --show-trace

[linux]
[group('vps')]
OVH-CA-EAST-BHS-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch OVH-CA-EAST-BHS {{mode}}
