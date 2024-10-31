{ lib, ... }:

{
  imports = [
    ../.
    ../amd/shared.nix
    ../nvidia/shared.nix
    ../../../../common/gpu/nvidia/prime.nix
  ];

  hardware.nvidia = {
    # Specify the bus ID for amd/nvidia devices
    prime = {
      amdgpuBusId = lib.mkDefault "PCI:5:0:0";
      nvidiaBusId = lib.mkDefault "PCI:1:0:0";
    };
    # Enable dynamic power management # Doesn't seem to work
    # powerManagement.finegrained = lib.mkDefault true;
  };
}
