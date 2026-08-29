# Architecture

Infinity OS uses this repository as source of truth and deploys into a target Arch system only when explicitly invoked.

## Layers

1. **Base/system**: package manifests, boot, services, hardware policy.
2. **Desktop**: Hyprland, Quickshell contracts, lock screen, greeter, themes, app integrations.
3. **User overrides**: files under `user/overrides/` and target-side override paths load last and are never replaced by routine updates.

## Decisions

- First milestone is a setup repository, not an ISO.
- Boot path is systemd-boot + mkinitcpio + Plymouth templates with recovery guidance.
- Greeter path is greetd + Cage + a non-interactive Quickshell visual layer + ReGreet authentication, with tuigreet recovery.
- Lock path is hypridle + real hyprlock; Quickshell must not fake locking.
- Portal path is xdg-desktop-portal + xdg-desktop-portal-hyprland + GTK fallback.
- Theme application generates target files, snapshots prior regular files, performs symlink-safe atomic replacements, and restores the full snapshot if any replacement fails.
- Ryoku is a cohesion reference only; no copied art, source, names, or palettes.

## Desktop shell data flow

Quickshell creates one scene per monitor. Its top navbar reads small global services rather than owning system commands itself:

- `Workspaces.qml` uses Quickshell's Hyprland IPC model for focused and occupied workspaces. It refreshes monitor metadata because Hyprland exposes special-workspace state there.
- `SystemResources.qml` samples `/proc/stat` and `/proc/meminfo` every two seconds. It computes CPU usage from two samples and reports unavailable values as `--` rather than inventing data.
- `Network.qml` reads NetworkManager through fixed `nmcli` argument arrays every five seconds.
- `Power.qml` reads UPower and power-profiles-daemon every ten seconds. Machines without a battery show AC power explicitly.
- `Theme.qml` and `Wallpaper.qml` keep preview state in memory. Committing still goes through `infinity-theme`, preserving its atomic writes and rollback boundary.

The appearance chooser is a monitor-local fullscreen layer-shell overlay. Arrow keys preview an edition, Enter commits it, and Escape clears the in-memory preview without writing. `WallpaperSurface.qml` remains on the background layer and combines crossfading images with a low-resolution animated grain field and scanline; reduced-motion mode stops perpetual movement and collapses transition durations.

Hyprland special workspaces contain ordinary application windows. Ordinary windows cannot reliably render above Quickshell's top or overlay layer-shell surfaces. Therefore, when a special workspace becomes active on a monitor, that monitor's scene closes popups and hides the navbar and OSD. This creates the requested unobstructed special workspace without weakening compositor or lock-screen boundaries. Other monitors remain visible.

## Deployment flow

`install.sh` parses target/root/user/stage options and delegates to `installation/lib/installer.sh`. Stages are idempotent where practical and plan-visible. Config deployment uses `bin/infinity-deploy`, `deployment/mappings.tsv`, and timestamped backups for conflicts.

## End-to-end flow

`firmware → systemd-boot → kernel/initramfs + Plymouth → systemd → greetd/Cage/ReGreet → Hyprland → Quickshell → applications`

The repository currently implements the source definitions and safe deployment slice. Boot rendering, package application, service enablement, and greeter login still require a VM integration stage before they can be called operational.
