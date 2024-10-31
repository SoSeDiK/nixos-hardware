{ config, ... }:

{
  imports = [
    ../../../common/cpu/amd/pstate.nix
    ../../../common/pc/laptop
    ../../../common/pc/ssd
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ lenovo-legion-module ];
}
