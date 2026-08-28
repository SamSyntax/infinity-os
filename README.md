# Infinity OS

Infinity OS is a repository-driven Arch workstation foundation. It is not an ISO. The current milestone installs and validates a cohesive Hyprland + Quickshell desktop foundation.

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
5. Apply only inside the VM after reviewing the plan:
   ```sh
   sudo ./install.sh --target-root / --target-user youruser --confirm
   ```
   Root is required because deployment writes greetd configuration under `/etc` and shared greeter artwork under `/usr/share`. Existing mapped user configuration is copied to `~/.local/share/infinity-os/backups/` before replacement. The deployment record is `~/.local/share/infinity-os/deployment-manifest.json`.

The installer never partitions disks. Plan mode is the safe development default. Apply mode currently deploys configuration and the selected theme; package, hardware, service enablement, and boot rendering stages are still explicit plan-only foundations.

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
./bin/infinity-validate
./bin/infinity-theme list
./bin/infinity-theme preview aurora
./bin/infinity-theme preview signal-archive
./bin/infinity-theme apply aurora --dry-run --target-root /tmp/infinity-os-theme --target-user testuser
```

## Current status

- Implemented and repository-tested: staged plan/apply CLI, grouped package manifests, symlink-safe deployment with backups and a manifest, modular Hyprland Lua, theme schema/rollback CLI, three original themes and wallpapers, and one validation command.
- Implemented and runtime-loaded on the development host: modular Quickshell wallpaper, rail, expandable system-state surface, launcher shell, OSD, shared theme service, and animated theme previews.
- Template-only, not applied or VM-tested yet: systemd-boot/Plymouth rendering, package installation, hardware selection, service enablement, greetd/ReGreet login, and the hypridle/hyprlock lifecycle.
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
