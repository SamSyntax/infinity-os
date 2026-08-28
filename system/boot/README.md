# Boot foundation

Infinity uses systemd-boot templates in this directory and Plymouth for a quiet branded boot path. The fallback entry boots to multi-user target for recovery.

Before applying on a real target:

1. Replace `@ROOT_UUID@` with the target root filesystem UUID.
2. Replace `@MICROCODE_IMAGE@` with `intel-ucode.img` or `amd-ucode.img` for the detected CPU. Including both would make the entry depend on an image that may not exist.
3. Decide whether encryption and resume hooks are required.

These files remain reviewed templates until the boot stage learns to discover and render target-specific values safely.
