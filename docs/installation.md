# Installation model

`install.sh` is a thin strict-mode entry point. Supported stages:

`preflight,repositories,packages,base,hardware,wayland,desktop-shell,applications,services,boot,greeter,themes,deploy,validate,preview`

Apply-capable stages:

`preflight,packages,services,themes,deploy,validate,preview`

Plan mode:

```sh
./install.sh --plan --target-root / --target-user sam --stage preflight --stage deploy
```

Apply mode requires `--confirm` and should be run only on a target VM/system:

```sh
./install.sh --confirm --target-root /mnt/infinity-root --target-user sam --stage preflight --stage themes --stage deploy --stage validate
```

If `--confirm` includes any plan-only stage, the installer exits before creating its log directory or writing files and names the unsupported stages in the error. Use `--plan` for the full stage list.

The two package-changing apply stages, `packages` and `preview`, must each be selected by themselves. The offline `services` apply stage is also standalone. These boundaries prevent package transactions, offline system links, deployment, boot, greeter, and theme writes from sharing one failure domain.

No stage partitions disks. Hardware and graphics stages report decisions and package groups; they do not assume NVIDIA/AMD/Intel globally.

Logs are written under `<target-root>/var/log/infinity-os/` when applying. Log creation and append use symlink-safe regular-file operations and reject symlinked parents or log files. Plan mode writes nothing and streams the proposed actions to standard output.

## Standalone official packages stage

The `packages` stage installs the broader official workstation package groups without turning on the desktop yet.

Plan first:

```sh
./install.sh --plan --stage packages
```

The plan writes nothing. It may read `/usr/bin/systemd-detect-virt --quiet` and `/proc/cpuinfo` to show the same microcode decision apply mode will use. It prints:

- package manifests and the exact pacman argv will be validated before any package write and before log creation;
- the selected CPU microcode result;
- that graphics and AUR packages are deferred;
- that services, boot, greeter, deploy, and theme actions are excluded;
- the exact absolute pacman argv.

Apply on the live Arch system only:

```sh
./install.sh --confirm --stage packages
```

When this command is started by a normal user, the installer validates the live-root preflight and then asks for sudo authentication. It re-executes itself with canonical arguments before creating the system log or invoking pacman. Running the same reviewed command as root also remains supported.

Safety and scope:

1. The resolved target root must be `/`. This stage does not chroot and does not install into `/mnt`.
2. Apply runs with effective UID 0. A normal-user invocation requests that elevation through `/usr/bin/sudo`; plan mode never elevates.
3. `/usr/bin/pacman` must exist and be executable. The installer does not use a `PATH`-resolved pacman.
4. Package manifests, the complete package list, and the fixed pacman argv are validated before log creation or any target write. The full developer validator is not run by this stage; run `./bin/infinity-validate` as your normal user first.
5. The package-changing command is exactly `/usr/bin/pacman -Syu --needed --noconfirm -- ...`.

`-Syu` means: sync package databases (`-y`), upgrade the system as needed (`-u`), and install the requested packages (`-S`) in one transaction. This follows Arch’s rule that package installation should not happen against a partially upgraded system. `--needed` avoids reinstalling packages that are already current, `--noconfirm` is gated by the installer-level `--confirm`, and `--` ends pacman options before package names.

Included official groups, merged in this order with first occurrence preserved: `base`, `hardware`, `wayland`, `desktop-shell`, `applications`. The selector deliberately never reads `graphics.official.txt` or `aur.txt` for this stage. Both `intel-ucode` and `amd-ucode` are removed from the hardware group first; then production detection adds at most one: none in a VM/container, `intel-ucode` on bare-metal GenuineIntel, `amd-ucode` on bare-metal AuthenticAMD. Unknown bare-metal vendors fail before log creation or pacman.

Failure recovery: if pacman returns nonzero, the installer exits immediately after printing/logging that package state may have changed, no removal was attempted, and the recovery action is to resolve the pacman error and rerun `./install.sh --confirm --stage packages`.

## Offline system services stage

The `services` stage enables the smallest boot-time system set in an already populated, mounted Arch root. A system service is a background program managed by systemd; enabling it means adding a link beneath a target such as `multi-user.target.wants`, so systemd includes it during a future boot. This stage does not run the service.

Plan first without root privileges or writes:

```sh
./install.sh --plan --target-root /mnt/infinity-root --target-user sam --stage services
```

Apply only while the target is offline:

```sh
./install.sh --confirm --target-root /mnt/infinity-root --target-user sam --stage services
```

The normal-user command checks that the resolved root is not `/` and lacks the usual systemd runtime markers, replaces the supplied path with that canonical root, then re-executes through `/usr/bin/sudo` with canonical arguments. It must be the only selected stage. After elevation, the installer requires every target-path component to be root-owned and not group/world-writable; this prevents an unprivileged process from replacing the canonical path between privileged phases. It then validates the complete manifest, all installed source units, every parent directory, and every existing destination before creating the log or a service link.

The policy in `system/services/enabled-system-units.tsv` declares each unit, target, and owning official package. Repository validation requires each provider to remain in an official package manifest. It creates exactly these links:

- `multi-user.target.wants/NetworkManager.service` for network management;
- `bluetooth.target.wants/bluetooth.service` for Bluetooth hardware;
- `multi-user.target.wants/power-profiles-daemon.service` for power-mode selection.

Each link points to its absolute unit path under `/usr/lib/systemd/system/` in the future booted target. The implementation uses descriptor-relative filesystem operations with no-follow checks instead of contacting a running manager. Missing installed units, symlinked parents or source units, ordinary files at destinations, and wrong existing links fail without replacement. An exact existing link is accepted, making reruns idempotent.

This stage creates missing `multi-user.target.wants` and `bluetooth.target.wants` directories as needed, writes the three enablement links, and atomically maintains `<target-root>/var/log/infinity-os/install.log`. It does not install packages, invoke process-control tools, enter a chroot, or configure boot, greetd, user sessions, portals, audio, or idle behavior. Greetd, SSH, portals, UPower, PipeWire, WirePlumber, and hypridle remain deferred because they need later security decisions or are activated through sockets, D-Bus, or user sessions.

Recovery: validation failures happen before all writes, including the log. If a low-level I/O failure occurs after link creation starts, already-correct links remain; fix the reported target filesystem problem and rerun the same command. Conflicting target entries are never removed automatically. Rejecting `/` and visible runtime markers is a practical offline check, not proof across every mount namespace, so the operator must still ensure the target is not currently booted or managed elsewhere.

## Manual VM preview stage

The `preview` stage is a small bridge from “repository scaffold” to “manually launchable desktop”. It is for an already bootable vanilla Arch VM with a normal non-root user at `/home/<user>`.

Plan first:

```sh
./install.sh --plan --stage preview --target-user sam
```

The plan writes nothing. It names four actions: validate the repository, install the preview package set, deploy user-scoped files, and apply the `Signal Archive` theme.

Apply inside the VM only:

```sh
./install.sh --confirm --stage preview --target-user sam
```

The normal-user command performs live-root and target-account preflight checks, then asks for sudo authentication before validation, system logging, or package changes. In the elevated process, the repository validator, user deployment, and theme application explicitly run as `sam`; only the installer log and package transaction remain root-owned operations.

What this writes:

1. It validates the repository before any package change. Invalid source files stop the run before pacman.
2. It runs one official package transaction: `/usr/bin/pacman -Syu --needed --noconfirm -- ...`. `-Syu` syncs package databases and upgrades the VM as part of installing the preview packages. `--noconfirm` is acceptable here only because the installer-level `--confirm` is the explicit confirmation gate. The `--` separates pacman options from package names.
3. It deploys only user mappings under `/home/sam`, such as Hyprland, Quickshell, hyprlock, and hypridle configuration. Existing user files are backed up under `/home/sam/.local/share/infinity-os/backups/` before replacement. It deliberately skips system mappings such as greetd and shared greeter wallpaper.
4. It applies the `Signal Archive` theme to user configuration and current wallpaper state.
5. It writes an installer log under `/var/log/infinity-os/install.log`.

Safety boundaries:

- `preview` apply only accepts the resolved target root `/`. It never installs packages into a chroot or arbitrary target root.
- The apply process must become UID 0 for the system log and pacman. A normal-user invocation requests this through `/usr/bin/sudo`; repository validation and user-home deployment then drop back to the target user.
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
- This remains a preview, not the full Infinity installer. Default `./install.sh --confirm` still fails before elevation because unrelated stages remain plan-only.
