{ ... }:

{
  imports = [
    ../.
    ./shared.nix
    ../../../../common/gpu/nvidia/disable.nix
  ];
}
