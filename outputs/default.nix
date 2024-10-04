inputs @ { self
, ...
}:
let
  inherit (inputs.nixpkgs) lib;
  mylib = import ../lib { inherit lib; };
  myvars = import ../vars { inherit lib; };

  nixosSystem = import ../lib/nixosSystem.nix;
  home-module = import ../home/linux/desktop.nix;
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
in
{
  nixosConfigurations =
    let
      specialArgs = genSpecialArgs "x86_64-linux";

      args = {
        inherit inputs mylib myvars specialArgs home-module;
      };
    in
    {
      DESKTOP-NixOS = nixosSystem args;
    };
}
