{ config, lib, ... }:

{
  imports = [
    ../../surface/common
    ../../../common/pc/laptop
    ../../../common/pc/ssd
    ../../../common/cpu/intel
    ../../../common/gpu/nvidia/prime.nix
    ../../../common/gpu/nvidia/turing
  ];

  # Specify bus id of Nvidia and Intel graphics.
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
  };

  boot.extraModprobeConfig = lib.concatStringsSep "\n" (
    [
      # Enable supported NVIDIA features
      ("options nvidia " + lib.concatStringsSep " " [
        # Use PAT
        "NVreg_UsePageAttributeTable=1"
        # Enable PCIe Gen 3.x support
        "NVreg_EnablePCIeGen3=1"
      ])
    ] ++ lib.optionals (config.hardware.nvidia.powerManagement.enable && !config.hardware.nvidia.powerManagement.finegrained) [
      # Enable Dynamic Power Management (disabled by default on Turing)
      "options nvidia NVreg_DynamicPowerManagement=0x01"
    ]
  );

  hardware.nvidia = {
    # Helps with sleep/suspend issues
    powerManagement = {
      enable = lib.mkDefault true;
      finegrained = lib.mkDefault true;
    };
  };
}
