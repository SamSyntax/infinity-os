# Hardware policy

Hardware handling is detection-led and conservative.

- CPU microcode: manifests may mention both `intel-ucode` and `amd-ucode`, but the standalone `packages` stage removes both before final selection. In a VM/container it installs no guest microcode. On bare metal it reads `/proc/cpuinfo` and adds exactly one package: `intel-ucode` for `GenuineIntel` or `amd-ucode` for `AuthenticAMD`. Unknown bare-metal vendors stop the run before log creation or pacman.
- GPU: graphics packages are intentionally excluded from the standalone `packages` stage. `system/packages/graphics.official.txt` records future conditional choices such as Mesa/Vulkan and `nvidia-open`, but GPU driver installation still needs target-specific review and is not automatic.
- Laptop support: brightness, power profiles, battery status, Bluetooth, and suspend policies are grouped but not forced beyond standard services.
- Displays: Hyprland defaults use preferred/auto monitor configuration. Machine-specific monitor and device overrides belong in user override files.
- Hibernate/resume and encryption are not assumed by boot templates.
