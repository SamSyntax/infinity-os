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
   ./bin/infinity-theme preview verdigris-ledger
   ./bin/infinity-theme apply signal-archive --dry-run --target-user "$USER"
   ```
   These commands only read theme data or print planned user-home writes. `Signal Archive` is the original warm-monochrome, halftone/distortion edition.
5. Review the standalone official workstation package transaction:
   ```sh
   ./install.sh --plan --stage packages
   ```
   This writes nothing. It validates that package selection would happen before any target write, prints the detected CPU microcode decision, states that graphics drivers and AUR packages are deferred, and prints the exact `/usr/bin/pacman -Syu --needed --noconfirm -- ...` argv. Run the full `./bin/infinity-validate` command as your normal user first; the package stage deliberately validates only its manifests and fixed pacman argv instead of executing repository tests as root.
6. Apply the broader official package groups only on the live root of the Arch VM/system:
   ```sh
   ./install.sh --confirm --stage packages
   ```
   `packages` is intentionally standalone like `preview`: it must be the only selected apply stage and only accepts the resolved target root `/`. A normal-user invocation asks for sudo once, then re-executes with canonical arguments before logging or pacman. It installs one official package transaction for `base`, `hardware`, `wayland`, `desktop-shell`, and `applications`, in that order. It removes both microcode packages from manifests first, then adds at most one production choice: no microcode in a VM/container, `intel-ucode` on bare-metal GenuineIntel, or `amd-ucode` on bare-metal AuthenticAMD. Unknown bare-metal CPU vendors fail before log creation or pacman. It does not install graphics/AUR packages, enable services, touch boot/greeter files, deploy dotfiles, or apply themes. If pacman exits nonzero, package state may have changed; no removal is attempted, so resolve pacman and rerun the same stage.
7. Enable the minimal system services only inside an offline mounted Arch root:
   ```sh
   ./install.sh --plan --target-root /mnt/infinity-root --target-user youruser --stage services
   ./install.sh --confirm --target-root /mnt/infinity-root --target-user youruser --stage services
   ```
   The confirmed command must be selected by itself and requests sudo when needed. It validates every operation before creating the installer log, then creates missing `*.target.wants` directories and fixed links for NetworkManager, Bluetooth, and power-profiles-daemon. It never invokes a service manager or starts a process, rejects `/`, active systemd runtime markers, and privileged target paths that are not root-owned or are group/world-writable, and preserves conflicting files or links for manual review. The installed unit files under `/usr/lib/systemd/system/` must already exist, so run this only after packages have been installed into that offline root. Greetd, SSH, portals, UPower, PipeWire, WirePlumber, and hypridle remain deferred.
8. Install the login greeter only on the live, booted Arch VM/system:
   ```sh
   ./install.sh --plan --stage greeter
   ./install.sh --confirm --stage greeter
   ```
   Plan mode writes nothing and needs no root privileges. Confirmed apply must be launched as a normal user from a reviewed source copy whose path and required files are root-owned and not group/world-writable; the user-owned development checkout is rejected before sudo. It must be selected by itself, accepts only the resolved root `/`, hashes the fixed greeter inputs, and asks sudo to execute only a revalidated ephemeral root-owned snapshot. It validates all packages, executables, the `greeter` account, Hyprland session descriptor, target paths, and display-manager conflicts before writing the installer log. It installs the tuigreet recovery configuration first, the primary greetd configuration after all visual assets, and the exact `display-manager.service` link last. Existing managed files are backed up under `/var/lib/infinity-os/backups/greeter/`; failures roll back completed writes in reverse order, retaining a backup if restoration itself fails. It never calls `systemctl`, so greetd is selected for the next boot without interrupting the current session. Login remains greetd's regular package-provided username/password flow; the stage does not customize PAM or add autologin. Filesystem behavior is repository-tested, but real authentication and login handoff still require QEMU verification.
9. Apply a minimal manual Hyprland + Quickshell preview only inside the already bootable VM:
   ```sh
   ./install.sh --confirm --stage preview --target-user youruser
   ```
   This is not the full installer. It asks for sudo because it runs one official `/usr/bin/pacman -Syu --needed --noconfirm -- ...` transaction, which performs a full system package database sync/upgrade before installing the preview packages. It only supports the live VM root `/`; it does not chroot into arbitrary target roots. The elevated process runs the repository validator, deployment, and theme application as `youruser`; only system logging and pacman remain privileged. After packages install, the installer deploys only user-owned mappings under `/home/youruser` with the normal backup behavior, applies the `Signal Archive` theme, and prints exact TTY launch instructions. If user deployment or theme application later fails, packages may remain installed; fix the reported issue and rerun the same command.

   To launch, log out or switch to a TTY, log in as `youruser`, then run:
   ```sh
   Hyprland --config "$HOME/.config/hypr/hyprland.lua"
   ```
   Use `Super+Return` to open Ghostty and `Super+Shift+M` to exit Hyprland back to the TTY. VM 3D acceleration may be required for Hyprland to start.
10. Apply the older staged repository deployment only inside a mounted test root after reviewing the plan:
   ```sh
   ./install.sh --confirm --target-root /mnt/infinity-root --target-user youruser --stage preflight --stage themes --stage deploy --stage validate
   ```
   This only applies the selected deployment stages. The default `--confirm` run fails fast because the full stage list still includes plan-only stages such as base, hardware, wayland, desktop-shell, applications, and boot. Use a writable mounted target root; existing mapped user configuration is copied to `~/.local/share/infinity-os/backups/` before replacement. The deployment record is `~/.local/share/infinity-os/deployment-manifest.json`.

The installer never partitions disks. Plan mode is the safe development default. Apply mode currently works for `preflight`, `themes`, `deploy`, `validate`, the standalone offline-root-only `services` stage, and the standalone live-root-only `packages`, `greeter`, and `preview` stages; the remaining stages are plan-only and make default `--confirm` fail before any writes.

## Isolated runtime testing

For fast desktop checks on a Wayland host, run `./launch-nested.sh --smoke`. It deploys to a unique ignored directory under `.runtime/nested/`, opens a nested Hyprland window, verifies workspace and theme behavior, checks process survival and rendering, then exits. It never needs root and does not write live dotfiles. Interactive mode is `./launch-nested.sh`.

For VM capability checks, run `./bin/infinity-qemu-smoke --check`. To boot an existing guest without changing its disk, run `./bin/infinity-qemu-smoke --image /path/to/guest.qcow2`; KVM, virtio GPU GL, and `-snapshot` are enforced. This proves the accelerated QEMU launch path, not guest boot correctness. See [Runtime testing](docs/runtime-testing.md) for writes, logs, recovery, and success criteria.

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
./install.sh --plan --stage packages
./install.sh --plan --target-root /tmp --stage services
./install.sh --plan --stage greeter
./install.sh --plan --stage preview --target-user testuser
./install.sh --confirm --stage packages
./install.sh --confirm --target-root /mnt/infinity-root --target-user testuser --stage services
./install.sh --confirm --stage greeter
./install.sh --confirm --target-root /tmp/infinity-root --target-user testuser --stage preflight --stage themes --stage deploy --stage validate
./bin/infinity-validate
./bin/infinity-theme list
./bin/infinity-theme preview aurora
./bin/infinity-theme preview signal-archive
./bin/infinity-theme apply aurora --dry-run --target-root /tmp/infinity-os-theme --target-user testuser
./launch-nested.sh --smoke
./bin/infinity-qemu-smoke --check
```

## Current status

- Implemented and repository-tested: staged plan/apply CLI, standalone live-root-only official package and greeter stages, standalone offline-root service enablement, live-root-only preview stage, grouped package manifests, symlink-safe deployment/logging with backups and manifests, modular Hyprland Lua, theme schema/rollback CLI, six original archive-style themes and wallpapers, and one validation command.
- Implemented and repository-tested: a slim grouped top navbar with live Hyprland workspaces, concise UPower state, geometric network status, date/time, launcher, controls, and real lock action; exclusive live-network and month-calendar popups; a monitor-local fullscreen appearance archive with preview/commit/cancel; atomic theme and wallpaper flows; crop-aware animated archival wallpaper rows; reduced-motion-aware grain, scanline, and wallpaper transitions; special-workspace shell suppression; themed hyprlock animations; and a non-interactive animated greeter layer behind ReGreet.
- Implemented but not applied or VM-tested: greetd/ReGreet file deployment, display-manager selection, and recovery rollback. Template-only or still awaiting system integration: systemd-boot/Plymouth rendering, graphics-driver selection, greetd/ReGreet authentication and session handoff, and the full hypridle/hyprlock lifecycle. Service and display-manager links are repository-tested, but boot-time activation still needs a VM.
- Mocked/placeholder backends: Bluetooth, media, and unsolicited OSD system events. Launcher indexing is curated rather than desktop-file driven. Network, battery/power, CPU/memory, and Hyprland workspace state are live and show explicit unavailable states when their providers are absent.
- Host-tested: isolated nested Hyprland/Quickshell startup, Super workspace switching, sandbox-only theme reload, process survival, host-state preservation, and the KVM/virgl QEMU launch path. Guest boot, greetd/ReGreet, hyprlock authentication, and enabled-service startup still require a bootable VM test image.

## Learn the implementation

- [Architecture](docs/architecture.md) explains ownership and data flow.
- [Decisions](docs/decisions.md) records consequential choices and tradeoffs.
- [Installation](docs/installation.md) explains installer stages and safety.
- [Deployment](docs/deployment.md) explains target paths, backups, and symlink protection.
- [Theme system](docs/theming.md) explains list, preview, apply, rollback, and generated files.
- [Runtime testing](docs/runtime-testing.md) explains nested desktop and accelerated QEMU feedback loops.
- [Compatibility matrix](docs/compatibility/keybindings.md) records preserved workflows and pending migrations.

## Project name and CLI

The working product/CLI name is **Infinity**. User-facing commands are `infinity-theme`, `infinity-validate`, `infinity-deploy`, and small helper commands under `bin/`.
