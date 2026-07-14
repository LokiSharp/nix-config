inputs@{
  self,
  nixpkgs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  mylib = import ../lib { inherit lib; };
  myvars = import ../vars { inherit lib; };

  genSpecialArgs =
    system:
    inputs
    // {
      inherit mylib myvars;

      # use unstable branch for some packages to get the latest updates
      pkgs-unstable = import inputs.nixpkgs-unstable {
        localSystem = system;
        config.allowUnfree = true;
      };
      pkgs-stable = import inputs.nixpkgs-stable {
        localSystem = system;
        config.allowUnfree = true;
      };
    };

  args = {
    inherit
      inputs
      lib
      mylib
      myvars
      genSpecialArgs
      ;
  };
  nixosSystems = {
    x86_64-linux = import ./x86_64-linux (args // { system = "x86_64-linux"; });
  };

  darwinSystems = {
    aarch64-darwin = import ./aarch64-darwin (args // { system = "aarch64-darwin"; });
  };

  allSystems = nixosSystems // darwinSystems;
  allSystemNames = builtins.attrNames allSystems;
  nixosSystemValues = builtins.attrValues nixosSystems;
  darwinSystemValues = builtins.attrValues darwinSystems;
  allSystemValues = nixosSystemValues ++ darwinSystemValues;
  nixosConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.nixosConfigurations or { }) nixosSystemValues
  );
  darwinConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.darwinConfigurations or { }) darwinSystemValues
  );
  colmena = {
    meta =
      (
        let
          system = "x86_64-linux";
        in
        {
          # colmena's default nixpkgs & specialArgs
          nixpkgs = import nixpkgs {
            localSystem = system;
            config.allowUnfree = true;
          };
          specialArgs = genSpecialArgs system;
        }
      )
      // {
        # per-node nixpkgs & specialArgs
        nodeNixpkgs = lib.attrsets.mergeAttrsList (
          map (it: it.colmenaMeta.nodeNixpkgs or { }) nixosSystemValues
        );
        nodeSpecialArgs = lib.attrsets.mergeAttrsList (
          map (it: it.colmenaMeta.nodeSpecialArgs or { }) nixosSystemValues
        );
      };
  }
  // lib.attrsets.mergeAttrsList (map (it: it.colmena or { }) nixosSystemValues);

  # Helper function to generate a set of attributes for each system
  forAllSystems = func: (nixpkgs.lib.genAttrs allSystemNames func);
  formatTestReport =
    system: tests:
    lib.concatStringsSep "\n" (
      map (
        name:
        let
          result = tests.${name};
        in
        "[${result.status}] ${system}/${name}"
      ) (lib.lists.sort builtins.lessThan (builtins.attrNames tests))
    );
  evalTestFailures =
    lib.mapAttrs (
      _system: tests:
      lib.filterAttrs (_name: result: result.status != "PASS") tests
    ) (lib.mapAttrs (_system: it: it.evalTestReport or { }) allSystems);
  formatTestFailures =
    system: tests:
    lib.concatStringsSep "\n" (
      map (
        name:
        "[FAIL] ${system}/${name}"
      ) (lib.lists.sort builtins.lessThan (builtins.attrNames tests))
    );
in
{
  # Add attribute sets into outputs, for debugging
  debugAttrs = {
    inherit
      nixosSystems
      darwinSystems
      allSystems
      allSystemNames
      ;
  };

  # NixOS Hosts
  inherit nixosConfigurations;

  # Colmena - remote deployment via SSH
  inherit colmena;

  # macOS Hosts
  inherit darwinConfigurations;

  # Packages
  packages = forAllSystems (system: allSystems.${system}.packages or { });

  publicNixosHosts =
    let
      publicHostNames = lib.filter (
        name:
        let
          host = mylib.hosts.${lib.toLower name};
        in
        host.public.IPv4 != ""
    ) (builtins.attrNames nixosConfigurations);
      sortedUnique = values: lib.lists.sort builtins.lessThan (lib.lists.unique values);
    in
    lib.genAttrs publicHostNames (
      name:
      let
        host = mylib.hosts.${lib.toLower name};
        config = nixosConfigurations.${name}.config;
      in
      {
        ipv4 = host.public.IPv4;
        expectedOpenTcpPorts = sortedUnique ([ 22 ] ++ config.networking.firewall.allowedTCPPorts);
      }
    );

  # Eval Tests for all NixOS & darwin systems.
  evalTests = lib.lists.all (it: it.evalTests == { }) allSystemValues;
  evalTestResults = lib.mapAttrs (_system: it: it.evalTestResults or { }) allSystems;
  evalTestReport = lib.mapAttrs (_system: it: it.evalTestReport or { }) allSystems;
  inherit evalTestFailures;
  evalTestReportText =
    (lib.concatStringsSep "\n" (
      map (
        system:
        formatTestReport system allSystems.${system}.evalTestReport
      ) (lib.lists.sort builtins.lessThan allSystemNames)
    ))
    + "\n";
  evalTestFailureText =
    let
      text = lib.concatStringsSep "\n" (
        lib.filter (line: line != "") (
          map (
            system:
            formatTestFailures system evalTestFailures.${system}
          ) (lib.lists.sort builtins.lessThan allSystemNames)
        )
      );
    in
    lib.optionalString (text != "") (text + "\n");

  devShells = forAllSystems (system: {
    default = nixpkgs.legacyPackages.${system}.mkShell {
      packages = with nixpkgs.legacyPackages.${system}; [
        just
        colmena
        nixpkgs-fmt
      ];
    };
  });

  checks = forAllSystems (system: {
    # eval-tests per system wrapped in a dummy derivation
    eval-tests =
      let
        res = allSystems.${system}.evalTests == { };
      in
      nixpkgs.legacyPackages.${system}.runCommand "eval-tests" { } ''
        if [ "${builtins.toString res}" != "1" ]; then
          echo "Evaluation tests failed!"
          exit 1
        fi
        touch $out
      '';
  });
}
