# Lenovo Legion 5 15ARH05

## Choosing configuration

### Hybrid mode

`lenovo-legion-15arh05-hybrid` contains a setup for the `Hybrid mode` picked in the BIOS to utilize both integrated AMD and discrete NVIDIA GPUs.

By default it's setup to run in NVIDIA's PRIME Render Offload mode.

This is a generally recommended module for most setups.

### Discrete mode

`lenovo-legion-15arh05-nvidia` is for the `Discrete mode` picked in the BIOS to utilize only the NVIDIA GPU since the AMD iGPU is disabled on the hardware level.

Potentially offers higher graphical performance at the cost of higher power consumption.

> [!CAUTION]
> Running discrete mode module while in hybrid mode is not recommended and might cause issues/side effects.

### iGPU-only / Integrated mode

Meant for BIOS's `Hybrid mode`, `lenovo-legion-15arh05-amd` completely disables the discrete NVIDIA GPU to reduce power consumption.

The HDMI output won't work as it's bound to the NVIDIA GPU.

Alternatively, if you still want to use the NVIDIA GPU at some point (e.g. for PCI passthrough), you may instead use the hybrid mode and block the `nvidia` drivers from loading:

```nix
boot.blacklistedKernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" "nvidia_uvm" ];
```

### Using multiple modes simultaneously

You may use the "specialization" feature of Nix to have multiple configurations at once. For example:

```nix
{ inputs, ... }:

{
  # Hybrid mode by default
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-legion-15arh05-hybrid
  ];

  # Discrete NVIDIA-only
  specialisation.nvidia.configuration = {
    imports = [ inputs.nixos-hardware.nixosModules.lenovo-legion-15arh05-nvidia ];
    disabledModules = [ inputs.nixos-hardware.nixosModules.lenovo-legion-15arh05-hybrid ];
  };

  # iGPU-only
  specialisation.amd.configuration = {
    imports = [ inputs.nixos-hardware.nixosModules.lenovo-legion-15arh05-amd ];
    disabledModules = [ inputs.nixos-hardware.nixosModules.lenovo-legion-15arh05-hybrid ];
  };
}
```

## Known issues

### Screen backlight/brightness controls not working

When both GPUs are enabled, they each register a backlight handler. NVIDIA's `nvidia_0` happens to be the first one and may be picked by software by default, but the laptop's screen brightness is actually handled by AMD's `amdgpu_bl1`.

Depending on what software you use, you might be able to workaround this by providing the correct device, e.g. in case of brightnessctl: `brightnessctl s 80 -d amdgpu_bl1`.

Alternatively, you may monitor changes to `nvidia_0` and sync them to `amdgpu_bl1`, for example using the following systemd service:

<details>
  <summary>Example screen backlight sync</summary>

  ```nix
  { pkgs, ... }:

  # Sync nvidia backlight changes to amd
  let
    nvidiaDeviceId = "nvidia_0";
    amdDeviceId = "amdgpu_bl1";
    nvidia_max_brightness = 100;
    amdgpu_max_brightness = 255;
  in
  {
    systemd = {
      services.backlight-monitor = {
        description = "Sync nvidia backlight changes to amd";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.writeShellScript "backlight-monitor" ''
            nvidia_path=/sys/class/backlight/${nvidiaDeviceId}/actual_brightness
            if [ ! -f "$nvidia_path" ]; then
              return 0
            fi
            nvidia_brightness=$(cat $nvidia_path)
            scaled_brightness=$(expr $(expr $nvidia_brightness \* ${toString amdgpu_max_brightness}) / ${toString nvidia_max_brightness})
            echo "$scaled_brightness" > /sys/class/backlight/${amdDeviceId}/brightness
          ''}";
        };
      };
      paths.backlight-monitor = {
        description = "Monitor nvidia backlight changes";
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathModified = "/sys/class/backlight/${nvidiaDeviceId}/brightness";
        };
      };
    };
  }
  ```

</details>

### NVIDIA GPU still works when not in use in Hybrid mode

Unfortunately, while having the hardware capabilities, it seems like the device does not support the NVIDIA's fine-grained power control. Hybrid mode is setup to use the coarse-grained power control by default, which does not power off the NVIDIA GPU completely.

## Extras

### Software control over some hardware features

You may use `lenovo-legion` nixpkgs package ([LenovoLegionLinux](https://github.com/johnfanv2/LenovoLegionLinux)) to control features like the fan curve, battery conservation mode, rapid charging, etc. from both GUI and `legion_cli` helper apps. The required kernel module (`lenovo-legion-module`) to access legion-specific features is included by default.

### Notes on GPU passthrough

GPU passthrough is supported and works quite well. For dynamic GPU (un)linking in hybrid mode you need to sacrifice/disable DRM modesetting and PRIME offloading (which also disables finegrained power management).

<details>
  <summary>Example VFIO setup for GPU passthrough</summary>
  
  ```nix
  { lib, ... }:

  let
    vfioIds = [ "10de:1f95" "10de:10fa" ]; # The IOMMU ids for GPU passthrough
  in
  {
    # Hybrid mode as a base
    imports = [
      inputs.nixos-hardware.nixosModules.lenovo-legion-15arh05-hybrid
    ];

    # Configure kernel options to make sure IOMMU & KVM support is on
    boot = {
      kernelModules = [
        # "kvm-amd" # Should be specified already by the default hardware scan

        # Required modules for passthrough
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"

        # "amdgpu" # Loaded by nixos-hardware module
      ];
      blacklistedKernelModules = [
        # Prevent NVIDIA GPU from loading
        "nvidia"
        "nvidia_modeset"
        "nvidia_drm"
        "nvidia_uvm"
      ];
      kernelParams = [
        # Enable IOMMU only for passthrough devices
        "iommu=pt"
      ];
      extraModprobeConfig = lib.concatStringsSep "\n" [
        # Provide VFIO ids
        "options vfio-pci ids=${lib.concatStringsSep "," vfioIds}"
      ];
    };

    # Disable NVIDIA features preventing dynamic GPU (un)linking
    hardware.nvidia = {
      modesetting.enable = false;
      prime.offload.enable = false;
      # Requires offload
      powerManagement.finegrained = lib.mkForce false;
    };
  }
  ```
  
</details>

### Enabling the CPU Performance Scaling Driver

The device supports the `amd-pstate` kernel module for potential increased energy efficiency (notably, unlocking running on minimum CPU core frequency of 400 MHz instead of 1400 MHz), but may fall back to `acpi-cpufreq` due to CPPC being disabled by default in BIOS.

In this case, the following line will be printed in the kernel logs:

```
amd_pstate: the _CPC object is not present in SBIOS or ACPI disabled
```

CPPC is hidden in advanced BIOS options under `Device Manager > AMD CBS > NBIO Common Options > SMU Common Options > CPPC`.

You can check the currently used driver by running:

```sh
cpupower frequency-info
```

For more info about `amd-pstate`, see https://www.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html.
