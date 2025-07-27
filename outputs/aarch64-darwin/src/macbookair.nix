{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}@args:
let
  hostName = "MacbookAir";
  hostNameLower = lib.toLower hostName;

  modules = {
    darwin-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/darwin.nix"
        "modules/darwin"
        # host specific
        "hosts/darwin-${hostNameLower}"
      ])
      ++ [
        {
          modules.desktop.fonts.enable = true;
        }
      ];
    home-modules = map mylib.relativeToRoot [
      "home/darwin"
    ];
  };

  systemArgs = modules // args;
in
{
  # macOS's configuration
  darwinConfigurations.${hostName} = mylib.macosSystem systemArgs;
}
