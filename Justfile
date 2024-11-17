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

# Run eval tests
[group('nix')]
test:
  nix eval .#evalTests --show-trace --print-build-logs --verbose

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
#  Homelab - Kubevirt Cluster related commands
#
############################################################################

# Remote deployment via colmena
[linux]
[group('homelab')]
col tag:
  colmena apply --on '@{{tag}}' --verbose --show-trace

[linux]
[group('homelab')]
local name mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-switch {{name}} {{mode}}

# Build and upload a vm image
[linux]
[group('homelab')]
upload-vm name mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  upload-vm {{name}} {{mode}}

# Deploy all the KubeVirt nodes(Physical machines running KubeVirt)
[linux]
[group('homelab')]
lab:
  colmena apply --on '@virt-*' --verbose --show-trace

[linux]
[group('homelab')]
VM-Kubevirt-Node-1:
  colmena apply --on '@VM-Kubevirt-Node-1' --verbose --show-trace

[linux]
[group('homelab')]
VM-Kubevirt-Node-1-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch VM-Kubevirt-Node-1 {{mode}}

[linux]
[group('homelab')]
VM-Kubevirt-Node-2:
  colmena apply --on '@VM-Kubevirt-Node-2' --verbose --show-trace

[linux]
[group('homelab')]
VM-Kubevirt-Node-2-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch VM-Kubevirt-Node-2 {{mode}}

[linux]
[group('homelab')]
VM-Kubevirt-Node-3:
  colmena apply --on '@VM-Kubevirt-Node-3' --verbose --show-trace

[linux]
[group('homelab')]
VM-Kubevirt-Node-3-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch VM-Kubevirt-Node-3 {{mode}}

############################################################################
#
# Commands for other Virtual Machines
#
############################################################################

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
