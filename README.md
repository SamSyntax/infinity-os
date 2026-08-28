# Infinity OS

Infinity OS is a repository-driven Arch workstation foundation. It is not an ISO. The current milestone defines and validates a cohesive Hyprland + Quickshell desktop foundation; it does not yet install the complete workstation.

## Safe VM workflow

Use a virtual machine or sacrificial Arch installation. The current installer does not partition disks or install a base operating system, so start from an already bootable Arch system with a normal user account.

1. Copy this repository into the VM. No command in this step needs root privileges.
2. From the repository root, validate source files:
   ```sh
   ./bin/infinity-validate
   ```
   This reads repository files and uses temporary directories for deployment tests. Success is a sequence of `ok:` lines and exit status 0. It does not modify the desktop or system configuration.
3. Review the complete installation plan:
   ```sh
   ./install.sh --plan --target-root / --target-user "$USER"
   ```
   `--plan` prints every selected stage and target path without writing to `/`. No root privileges are required. Treat any `infinity install:` message or nonzero exit status as a failure.
4. Inspect the available themes:
   ```sh
   ./bin/infinity-theme list
   ./bin/infinity-theme preview signal-archive
   ./bin/infinity-theme apply signal-archive --dry-run --target-user "$USER"
   ```
   These commands only read theme data or print planned user-home writes. `Signal Archive` is the original warm-monochrome, halftone/distortion edition.
5. Apply a minimal manual Hyprland + Quickshell preview only inside the already bootable VM:
   ```sh
   sudo ./install.sh --confirm --stage preview --target-user youruser
   ```
   This is not the full installer. It requires root because it runs one official `/usr/bin/pacman -Syu --needed --noconfirm -- ...` transaction, which performs a full system package database sync/upgrade before installing the preview packages. It only supports the live VM root `/`; it does not chroot into arbitrary target roots. Before pacman runs, the repository validator must pass. After packages install, the installer deploys only user-owned mappings under `/home/youruser` with the normal backup behavior, applies the `Signal Archive` theme, and prints exact TTY launch instructions. If user deployment or theme application later fails, packages may remain installed; fix the reported issue and rerun the same command.

   To launch, log out or switch to a TTY, log in as `youruser`, then run:
   ```sh
   Hyprland --config "$HOME/.config/hypr/hyprland.lua"
   ```
   Use `Super+Return` to open Ghostty and `Super+Shift+M` to exit Hyprland back to the TTY. VM 3D acceleration may be required for Hyprland to start.
6. Apply the older staged repository deployment only inside a mounted test root after reviewing the plan:
   ```sh
   ./install.sh --confirm --target-root /mnt/infinity-root --target-user youruser --stage preflight --stage themes --stage deploy --stage validate
   ```
   This only applies the supported stages. The default `--confirm` run fails fast because the full stage list still includes plan-only stages such as base, hardware, wayland, desktop-shell, applications, services, boot, and greeter. Use a writable mounted target root; existing mapped user configuration is copied to `~/.local/share/infinity-os/backups/` before replacement. The deployment record is `~/.local/share/infinity-os/deployment-manifest.json`.

The installer never partitions disks. Plan mode is the safe development default. Apply mode currently works only for `preflight`, `themes`, `deploy`, `validate`, and the live-root-only `preview`; the other stages are plan-only and make default `--confirm` fail before any writes.

## How the pieces connect

1. **systemd-boot** selects the Linux kernel and initramfs. **Plymouth** is the graphical splash shown while that initramfs starts the system.
2. **greetd** starts a small **Cage** Wayland compositor containing **ReGreet**, which authenticates the user and starts Hyprland. A separate tuigreet file is retained as a text recovery option.
3. **Hyprland** is the Wayland compositor: it owns monitors, windows, workspaces, input, and preserved global shortcuts.
4. **Quickshell** is the QML desktop shell running inside Hyprland. It draws the wallpaper, rail, launcher foundation, system panel, OSD, and theme previews from shared tokens.
5. **hypridle** controls the idle timeline. It dims, invokes the real **hyprlock** security boundary, then turns displays off.
6. `infinity-theme` renders one theme bundle into Quickshell, Hyprland, Ghostty, tmux, and Neovim integration files with rollback if an update fails.

## Testable commands now

```sh
./install.sh --help
./install.sh --plan --target-root /tmp --target-user testuser
./install.sh --plan --stage preview --target-user testuser
./install.sh --confirm --target-root /tmp/infinity-root --target-user testuser --stage preflight --stage themes --stage deploy --stage validate
./bin/infinity-validate
./bin/infinity-theme list
./bin/infinity-theme preview aurora
./bin/infinity-theme preview signal-archive
./bin/infinity-theme apply aurora --dry-run --target-root /tmp/infinity-os-theme --target-user testuser
```

## Current status

- Implemented and repository-tested: staged plan/apply CLI, live-root-only preview stage, grouped package manifests, symlink-safe deployment/logging with backups and a manifest, modular Hyprland Lua, theme schema/rollback CLI, three original themes and wallpapers, and one validation command.
- Implemented and runtime-loaded on the development host: modular Quickshell wallpaper, rail, expandable system-state surface, launcher shell, OSD, shared theme service, and animated theme previews.
- Template-only, not applied or VM-tested yet: systemd-boot/Plymouth rendering, full package installation, hardware selection, service enablement, greetd/ReGreet login, and the hypridle/hyprlock lifecycle.
- Mocked/placeholder backends: launcher indexing/activation, live network/Bluetooth/power values, OSD system events, and theme-preview commit wiring.
- Runtime services are not claimed tested on this host.

## Learn the implementation

- [Architecture](docs/architecture.md) explains ownership and data flow.
- [Decisions](docs/decisions.md) records consequential choices and tradeoffs.
- [Installation](docs/installation.md) explains installer stages and safety.
- [Deployment](docs/deployment.md) explains target paths, backups, and symlink protection.
- [Theme system](docs/theming.md) explains list, preview, apply, rollback, and generated files.
- [Compatibility matrix](docs/compatibility/keybindings.md) records preserved workflows and pending migrations.

## Project name and CLI

The working product/CLI name is **Infinity**. User-facing commands are `infinity-theme`, `infinity-validate`, `infinity-deploy`, and small helper commands under `bin/`.
