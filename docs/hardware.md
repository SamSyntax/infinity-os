# Hardware policy

Hardware handling is detection-led and conservative.

- CPU microcode: include both Intel and AMD manifests; target hardware determines what is installed/enabled.
- GPU: Mesa baseline; AMD/Intel Vulkan packages are safe manifest entries; NVIDIA packages are conditional and require DRM KMS review on the target.
- Laptop support: brightness, power profiles, battery status, Bluetooth, and suspend policies are grouped but not forced beyond standard services.
- Displays: Hyprland defaults use preferred/auto monitor configuration. Machine-specific monitor and device overrides belong in user override files.
- Hibernate/resume and encryption are not assumed by boot templates.
