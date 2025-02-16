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
  colmena apply --on '@dn42' --verbose --show-trace

[linux]
[group('vps')]
NodeSet-LOKI-NET:
  colmena apply --on '@loki-net' --verbose --show-trace

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
SkyWolf-HK:
  colmena apply --on '@SkyWolf-HK' --verbose --show-trace

[linux]
[group('vps')]
SkyWolf-HK-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch SkyWolf-HK {{mode}}

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
OVH-CA-EAST-BHS:
  colmena apply --on '@OVH-CA-EAST-BHS' --verbose --show-trace

[linux]
[group('vps')]
OVH-CA-EAST-BHS-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch OVH-CA-EAST-BHS {{mode}}

############################################################################
#
# Kubernetes related commands
#
############################################################################

# Build and upload a vm image
[linux]
[group('homelab')]
upload-k3s-test mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  upload-iso K3S-Test-1-Master-1 {{mode}}; 
  upload-iso K3S-Test-1-Master-2 {{mode}}; 
  upload-iso K3S-Test-1-Master-3 {{mode}};

[linux]
[group('homelab')]
upload-k3s-prod mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  upload-iso K3S-Prod-1-Master-1 {{mode}}; 
  upload-iso K3S-Prod-1-Master-2 {{mode}}; 
  upload-iso K3S-Prod-1-Master-3 {{mode}};
  upload-iso K3S-Prod-1-Worker-1 {{mode}}; 
  upload-iso K3S-Prod-1-Worker-2 {{mode}}; 
  upload-iso K3S-Prod-1-Worker-3 {{mode}};

[linux]
[group('homelab')]
k3s-test:
  colmena apply --on '@k3s-test-*' --verbose --show-trace

[linux]
[group('homelab')]
k3s-prod:
  colmena apply --on '@k3s-prod-*' --verbose --show-trace