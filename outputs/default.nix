inputs @ { self
, nixpkgs
, ...
}:
let
  inherit (inputs.nixpkgs) lib;
  mylib = import ../lib { inherit lib; };
  myvars = import ../vars { inherit lib; };

  genSpecialArgs = system:
    inputs
    // {
      inherit mylib myvars;

      # use unstable branch for some packages to get the latest updates
      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    };

  args = { inherit inputs lib mylib myvars genSpecialArgs; };
  nixosSystems = {
    x86_64-linux = import ./x86_64-linux (args // { system = "x86_64-linux"; });
  };

  darwinSystems = {
    aarch64-darwin = import ./aarch64-darwin (args // {system = "aarch64-darwin";});
  };

  allSystems = nixosSystems // darwinSystems;
  allSystemNames = builtins.attrNames allSystems;
  nixosSystemValues = builtins.attrValues nixosSystems;
  darwinSystemValues = builtins.attrValues darwinSystems;
  allSystemValues = nixosSystemValues ++ darwinSystemValues;

  # Helper function to generate a set of attributes for each system
  forAllSystems = func: (nixpkgs.lib.genAttrs allSystemNames func);
in
{
  # Add attribute sets into outputs, for debugging
  debugAttrs = { inherit nixosSystems darwinSystems allSystems allSystemNames; };

  # NixOS Hosts
  nixosConfigurations =
    lib.attrsets.mergeAttrsList (map (it: it.nixosConfigurations or { }) nixosSystemValues);

  # Colmena - remote deployment via SSH
  colmena =
    {
      meta =
        (
          let
            system = "x86_64-linux";
          in
          {
            # colmena's default nixpkgs & specialArgs
            nixpkgs = import nixpkgs { inherit system; };
            specialArgs = genSpecialArgs system;
          }
        )
        // {
          # per-node nixpkgs & specialArgs
          nodeNixpkgs = lib.attrsets.mergeAttrsList (map (it: it.colmenaMeta.nodeNixpkgs or { }) nixosSystemValues);
          nodeSpecialArgs = lib.attrsets.mergeAttrsList (map (it: it.colmenaMeta.nodeSpecialArgs or { }) nixosSystemValues);
        };
    }
    // lib.attrsets.mergeAttrsList (map (it: it.colmena or { }) nixosSystemValues);

  # macOS Hosts
  darwinConfigurations =
    lib.attrsets.mergeAttrsList (map (it: it.darwinConfigurations or {}) darwinSystemValues);

  # Packages
  packages = forAllSystems (
    system: allSystems.${system}.packages or { }
  );

  # Eval Tests for all NixOS & darwin systems.
  evalTests = lib.lists.all (it: it.evalTests == { }) allSystemValues;

  checks = forAllSystems (
    system: {
      # eval-tests per system
      eval-tests = allSystems.${system}.evalTests == { };
    }
  );
}
