# Infinity OS

Infinity OS is a repository-driven Arch workstation foundation. It is not an ISO. The current milestone installs and validates a cohesive Hyprland + Quickshell desktop foundation.

## Safe VM workflow

1. Create a fresh Arch VM or disposable machine.
2. Install base Arch first; do not run this from the live ISO expecting disk partitioning.
3. Copy this repository to the target system.
4. Review the plan:
   ```sh
   ./install.sh --plan --target-root / --target-user "$USER"
   ```
5. Run validation before applying anything:
   ```sh
   ./bin/infinity-validate
   ./bin/infinity-theme list
   ./bin/infinity-theme preview nocturne
   ./bin/infinity-theme apply nocturne --dry-run --target-user "$USER"
   ```
6. Apply only on the VM/sacrificial target after reviewing the plan:
   ```sh
   sudo ./install.sh --target-root / --target-user youruser --confirm
   ```

The installer never partitions disks. Dry-run/plan mode is the default-safe path for development.

## Testable commands now

```sh
./install.sh --help
./install.sh --plan --target-root /tmp/infinity-os-plan --target-user testuser
./bin/infinity-validate
./bin/infinity-theme list
./bin/infinity-theme preview aurora
./bin/infinity-theme preview signal-archive
./bin/infinity-theme apply aurora --dry-run --target-root /tmp/infinity-os-theme --target-user testuser
```

## Current status

- Present: staged installer, package manifests, deployment mappings/backups, modular Hyprland Lua foundation, boot/Plymouth/greetd/ReGreet/hypridle/hyprlock templates, theme schema, two original themes and wallpapers, validation CLI.
- Present: a modular Quickshell visual slice with wallpaper, rail, expandable state, launcher, OSD, shared theme service, and animated theme previews.
- Pending: live launcher indexing, system control backends, and theme-preview commit wiring.
- Runtime services are not claimed tested on this host.

## Project name and CLI

The working product/CLI name is **Infinity**. User-facing commands are `infinity-theme`, `infinity-validate`, `infinity-deploy`, and small helper commands under `bin/`.
