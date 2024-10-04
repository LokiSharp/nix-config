inputs @ { self
, ...
}:
let
  username = "loki-sharp";
  userfullname = "LokiSharp";
  useremail = "loki.sharp@gmail.com";

  nixosSystem = import ../lib/nixosSystem.nix;
  home-module = import ../home/linux/desktop.nix;
  x64_system = "x86_64-linux";
in
{
  nixosConfigurations =
    let
      system = x64_system;

      specialArgs =
        {
          inherit username userfullname useremail inputs;

          pkgs-stable = import inputs.nixpkgs-stable {
            system = x64_system;
            config.allowUnfree = true;
          };

          pkgs-unstable = import inputs.nixpkgs-unstable {
            system = x64_system;
            config.allowUnfree = true;
          };
        };

      args = {
        inherit inputs specialArgs home-module;
      };
    in
    {
      DESKTOP-NixOS = nixosSystem args;
    };
}
