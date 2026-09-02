# Live-root greeter stage

## Goal

Add a standalone installer stage that prepares a booted Arch system to use
greetd with Infinity's ReGreet presentation on its next boot. The stage must not
start, restart, reload, or otherwise contact the running service manager.

## Invocation boundary

- The installer exposes `greeter` as an apply-capable stage.
- Apply is allowed only when `greeter` is the sole selected stage, the target
  root is `/`, the process has effective UID 0, and `--confirm` is present.
- Apply must be launched by a normal user from a previously reviewed source
  copy whose path, directories, code, and payloads are root-owned and not
  group/world-writable. A user-owned development checkout is rejected before
  sudo or target writes.
- The normal-user apply hashes the fixed code/payload set, then asks sudo to copy
  only descriptor-opened bytes matching those hashes into an ephemeral,
  root-owned `0700` snapshot. The privileged bootstrap rechecks source
  ownership, modes, file type, link count, and hashes through pinned no-follow
  descriptors. Root executes only that verified snapshot and removes it
  afterward. Direct root apply outside this trusted transition is rejected.
- Plan mode is read-only and does not require root or confirmation.
- Direct module tests may use a synthetic target root, but the public installer
  must reject non-live roots for greeter apply.

## Trusted inputs

The stage uses a fixed, repository-owned manifest. It has no CLI option for
arbitrary source paths, target paths, unit paths, users, or commands.

| Repository source | Target | Mode |
|---|---|---|
| `system/services/greetd-tuigreet-recovery.toml` | `/etc/greetd/config-tuigreet-recovery.toml` | `0644` |
| `desktop/greeter/start-greeter` | `/usr/lib/infinity-os/start-greeter` | `0755` |
| `desktop/greeter/regreet.toml` | `/etc/greetd/regreet.toml` | `0644` |
| `desktop/greeter/regreet.css` | `/etc/greetd/regreet.css` | `0644` |
| `desktop/greeter/shell.qml` | `/usr/share/infinity-os/greeter/shell.qml` | `0644` |
| `desktop/wallpapers/nocturne.svg` | `/usr/share/infinity-os/wallpapers/nocturne.svg` | `0644` |
| `system/services/greetd.toml` | `/etc/greetd/config.toml` | `0644` |

Recovery configuration is installed first. Primary `config.toml` is installed
after all supporting assets. The final mutation creates exactly:

```text
/etc/systemd/system/display-manager.service
  -> /usr/lib/systemd/system/greetd.service
```

## Complete preflight

Before the first target mutation or transaction log write, apply validates:

1. every manifest source exists, is a regular file, resolves inside the
   repository, and has the expected non-empty content;
2. every destination is absolute, unique, within the fixed allowlist, and can
   be reached without following target-root symlinks;
3. the expected Arch packages are installed;
4. required executables exist as safe regular files;
5. the `greeter` system account exists;
6. `/usr/share/wayland-sessions/hyprland.desktop` exists and declares a usable
   Hyprland session;
7. `/usr/lib/systemd/system/greetd.service` exists as a safe regular file;
8. the current `display-manager.service` path is absent or already the exact
   greetd symlink; any other file, symlink, or display-manager selection is a
   hard conflict and is not replaced automatically.

Preflight failures name what failed, explain that no target changes were made,
and give the next corrective action.

## Transaction and reruns

- Mutations use descriptor-safe, no-follow traversal and atomic replacement.
- Existing managed files are backed up before replacement.
- If any mutation fails, completed mutations are rolled back in reverse order.
- Backup deletion depends on successful restoration. If restoration itself
  fails, the backup is retained and the error identifies manual repair.
- The enablement symlink is created last, so an incomplete asset deployment
  cannot select greetd for the next boot.
- An identical rerun reports unchanged files and succeeds without new backups.
- No code path invokes `systemctl` or changes the current boot/session state.

## Recovery and security boundaries

- The recovery file preserves a known tuigreet configuration at
  `/etc/greetd/config-tuigreet-recovery.toml`; an operator can copy it over
  `/etc/greetd/config.toml` from a TTY or recovery environment.
- Login uses greetd's ordinary username/password flow through Arch's
  package-provided PAM configuration. The installer does not modify PAM,
  configure autologin, create accounts, or add alternative authentication.
- Package-provided `/etc/pam.d/greetd` and the `greeter` sysusers account remain
  package ownership boundaries.
- Actual greetd/ReGreet authentication and compositor handoff remain untested
  until the QEMU milestone. Repository tests prove filesystem transaction and
  configuration contracts, not a successful login.

## Verification

- Unit tests exercise plan/apply boundaries, complete preflight, conflicts,
  write ordering, idempotency, backups, rollback, and exact symlink creation in
  a repository-local synthetic root.
- Installer CLI tests prove root, confirmation, standalone-stage, and live-root
  enforcement without writing to the development machine.
- `bin/infinity-validate` includes the new tests and Python syntax checks.
