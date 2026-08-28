# Installation model

`install.sh` is a thin strict-mode entry point. Supported stages:

`preflight,repositories,base,hardware,wayland,desktop-shell,applications,services,boot,greeter,themes,deploy,validate`

Apply-capable stages:

`preflight,themes,deploy,validate`

Plan mode:

```sh
./install.sh --plan --target-root / --target-user sam --stage preflight --stage deploy
```

Apply mode requires `--confirm` and should be run only on a target VM/system:

```sh
./install.sh --confirm --target-root /mnt/infinity-root --target-user sam --stage preflight --stage themes --stage deploy --stage validate
```

If `--confirm` includes any plan-only stage, the installer exits before creating its log directory or writing files and names the unsupported stages in the error. Use `--plan` for the full stage list.

No stage partitions disks. Hardware and graphics stages report decisions and package groups; they do not assume NVIDIA/AMD/Intel globally.

Logs are written under `<target-root>/var/log/infinity-os/` when applying. Plan mode writes nothing and streams the proposed actions to standard output.
