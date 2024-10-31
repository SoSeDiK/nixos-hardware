{ lib, config, ... }:

{
  imports = [
    ../../../../common/gpu/nvidia/turing
  ];

  boot.extraModprobeConfig = lib.concatStringsSep "\n" [
    # Enable supported NVIDIA features
    ("options nvidia " + lib.concatStringsSep " " [
      # Use PAT
      "NVreg_UsePageAttributeTable=1"
      # Enable PCIe Gen 3.x support
      "NVreg_EnablePCIeGen3=1"
    ])
  ];

  hardware.nvidia = {
    # Helps with sleep/suspend issues
    powerManagement.enable = lib.mkDefault true;
    # Open source drivers are not ready yet, e.g. not working suspend:
    # https://github.com/NVIDIA/open-gpu-kernel-modules/issues/472
    open = lib.mkIf (config.hardware.nvidia.powerManagement.enable) false;
  };
}
