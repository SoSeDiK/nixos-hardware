{ ... }:

{
  imports = [
    ../../../../common/gpu/amd
  ];

  boot.kernelParams = [
    # Fixup screen backlight control
    "amdgpu.backlight=0"
  ];
}
