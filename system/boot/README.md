# Boot foundation

Infinity uses systemd-boot templates in this directory and Plymouth for a quiet branded boot path. The fallback entry boots to multi-user target for recovery.

Before applying on a real target, replace `@ROOT_UUID@` with the target root filesystem UUID and decide whether encryption/resume hooks are required. This foundation intentionally does not assume either.
