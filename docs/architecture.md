# Architecture

Infinity OS uses this repository as source of truth and deploys into a target Arch system only when explicitly invoked.

## Layers

1. **Base/system**: package manifests, boot, services, hardware policy.
2. **Desktop**: Hyprland, Quickshell contracts, lock screen, greeter, themes, app integrations.
3. **User overrides**: files under `user/overrides/` and target-side override paths load last and are never replaced by routine updates.

## Decisions

- First milestone is a setup repository, not an ISO.
- Boot path is systemd-boot + mkinitcpio + Plymouth templates with recovery guidance.
- Greeter path is greetd + ReGreet with tuigreet recovery.
- Lock path is hypridle + real hyprlock; Quickshell must not fake locking.
- Portal path is xdg-desktop-portal + xdg-desktop-portal-hyprland + GTK fallback.
- Theme application is file generation into a target state/config tree using staging + atomic rename.
- Ryoku is a cohesion reference only; no copied art, source, names, or palettes.

## Deployment flow

`install.sh` parses target/root/user/stage options and delegates to `installation/lib/installer.sh`. Stages are idempotent where practical and plan-visible. Config deployment uses `bin/infinity-deploy`, `deployment/mappings.tsv`, and timestamped backups for conflicts.
