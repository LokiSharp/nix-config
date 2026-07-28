{ inputs
, lib
, mylib
, myvars
, system
, genSpecialArgs
, ...
}:
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

  systemArgs = modules // {
    inherit
      inputs
      lib
      mylib
      myvars
      system
      genSpecialArgs
      ;
  };
in
{
  # macOS's configuration
  darwinConfigurations.${hostName} = mylib.macosSystem systemArgs;
}
