# Installation model

`install.sh` is a thin strict-mode entry point. Supported stages:

`preflight,repositories,base,hardware,wayland,desktop-shell,applications,services,boot,greeter,themes,deploy,validate,preview`

Apply-capable stages:

`preflight,themes,deploy,validate,preview`

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

Logs are written under `<target-root>/var/log/infinity-os/` when applying. Log creation and append use symlink-safe regular-file operations and reject symlinked parents or log files. Plan mode writes nothing and streams the proposed actions to standard output.

## Manual VM preview stage

The `preview` stage is a small bridge from “repository scaffold” to “manually launchable desktop”. It is for an already bootable vanilla Arch VM with a normal non-root user at `/home/<user>`.

Plan first:

```sh
./install.sh --plan --stage preview --target-user sam
```

The plan writes nothing. It names four actions: validate the repository, install the preview package set, deploy user-scoped files, and apply the `Signal Archive` theme.

Apply inside the VM only:

```sh
sudo ./install.sh --confirm --stage preview --target-user sam
```

What this writes:

1. It validates the repository before any package change. Invalid source files stop the run before pacman.
2. It runs one official package transaction: `/usr/bin/pacman -Syu --needed --noconfirm -- ...`. `-Syu` syncs package databases and upgrades the VM as part of installing the preview packages. `--noconfirm` is acceptable here only because the installer-level `--confirm` is the explicit confirmation gate. The `--` separates pacman options from package names.
3. It deploys only user mappings under `/home/sam`, such as Hyprland, Quickshell, hyprlock, and hypridle configuration. Existing user files are backed up under `/home/sam/.local/share/infinity-os/backups/` before replacement. It deliberately skips system mappings such as greetd and shared greeter wallpaper.
4. It applies the `Signal Archive` theme to user configuration and current wallpaper state.
5. It writes an installer log under `/var/log/infinity-os/install.log`.

Safety boundaries:

- `preview` apply only accepts the resolved target root `/`. It never installs packages into a chroot or arbitrary target root.
- The effective UID must be 0, normally from `sudo`, because pacman and deployment need privileges.
- The target user must exist, must not be UID 0, and its passwd home must be exactly `/home/<user>`.
- It does not enable greetd, edit bootloader files, partition disks, enable services, start Hyprland automatically, configure autologin, or fake locking.

Launch after success:

```sh
Hyprland --config "$HOME/.config/hypr/hyprland.lua"
```

Run that after logging out of any graphical session or after switching to a TTY with `Ctrl+Alt+F3` and logging in as the target user. In the preview, `Super+Return` opens Ghostty and `Super+Shift+M` exits Hyprland back to the TTY. Hyprland in a VM may require 3D acceleration; if it exits immediately, check the VM graphics settings before assuming the configuration is broken.

Rerun and recovery:

- Rerunning the same preview command is intended to be safe for repository-managed user files; changed existing files are backed up again before replacement.
- If pacman succeeds but later deployment or theme application fails, the installed packages may remain. Fix the actionable error, then rerun the preview command. The installer does not automatically remove packages because doing so could remove packages the user also wanted.
- This remains a preview, not the full Infinity installer. Default `sudo ./install.sh --confirm` still fails because unrelated stages remain plan-only.
