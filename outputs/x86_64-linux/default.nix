{ lib
, inputs
, ...
} @ args:
let
  inherit (inputs) haumea;
  testsSrc = ./tests;

  # Contains all the flake outputs of this system architecture.
  data = haumea.lib.load {
    src = ./src;
    inputs = args;
  };
  # nix file names is redundant, so we remove it.
  dataWithoutPaths = builtins.attrValues data;

  # Merge all the machine's data into a single attribute set.
  outputs = {
    nixosConfigurations = lib.attrsets.mergeAttrsList (map (it: it.nixosConfigurations or { }) dataWithoutPaths);
    packages = lib.attrsets.mergeAttrsList (map (it: it.packages or { }) dataWithoutPaths);
    # colmena contains some meta info, which need to be merged carefully.
    colmenaMeta = {
      nodeNixpkgs = lib.attrsets.mergeAttrsList (map (it: it.colmenaMeta.nodeNixpkgs or { }) dataWithoutPaths);
      nodeSpecialArgs = lib.attrsets.mergeAttrsList (map (it: it.colmenaMeta.nodeSpecialArgs or { }) dataWithoutPaths);
    };
    colmena = lib.attrsets.mergeAttrsList (map (it: it.colmena or { }) dataWithoutPaths);
  };
  testInputs = args // { inherit outputs; };
  testDirs = lib.filterAttrs (
    _name: type:
    type == "directory"
  ) (builtins.readDir testsSrc);
  evalTestResults = lib.mapAttrs (
    name: _:
    let
      testDir = testsSrc + "/${name}";
      callTest =
        test:
        test (builtins.intersectAttrs (builtins.functionArgs test) testInputs);
      actual = callTest (import (testDir + "/expr.nix"));
      expected = callTest (import (testDir + "/expected.nix"));
    in
    {
      inherit actual expected;
      passed = builtins.deepSeq actual (builtins.deepSeq expected (actual == expected));
    }
  ) testDirs;
in
outputs
  // {
  inherit data; # for debugging purposes
  inherit evalTestResults;
  evalTestReport = lib.mapAttrs (_name: result: {
    status = if result.passed then "PASS" else "FAIL";
    assertions = result.actual;
  }) evalTestResults;

  # NixOS's unit tests.
  evalTests = haumea.lib.loadEvalTests {
    src = testsSrc;
    inputs = testInputs;
  };
}
