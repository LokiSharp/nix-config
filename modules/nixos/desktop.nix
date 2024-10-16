{ pkgs
, ...
}: {
  imports = [
    ./base
    ../base.nix

    ./desktop
  ];
}
