# Installation model

`install.sh` is a thin strict-mode entry point. Supported stages:

`preflight,repositories,base,hardware,wayland,desktop-shell,applications,services,boot,greeter,themes,deploy,validate`

Plan mode:

```sh
./install.sh --plan --target-root / --target-user sam --stage preflight --stage deploy
```

Apply mode requires `--confirm` and should be run only on a target VM/system:

```sh
sudo ./install.sh --target-root / --target-user sam --confirm
```

No stage partitions disks. Hardware and graphics stages report decisions and package groups; they do not assume NVIDIA/AMD/Intel globally.

Logs are written under `<target-root>/var/log/infinity-os/` when applying. Plan mode writes nothing and streams the proposed actions to standard output.
