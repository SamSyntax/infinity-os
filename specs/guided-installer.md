# Guided no-argument VM installer

## User contract

Running `./install.sh` with no arguments starts the primary guided installation
path for an already bootable Arch VM. Any explicit argument keeps the existing
expert CLI semantics unchanged.

The guided path:

1. requires a real non-root target account, a live target root `/`, Arch
   package tooling, sudo, and an interactive terminal;
2. runs the repository validator before privileged or persistent writes;
3. fingerprints the fixed runtime/data closure and prints its bundle ID;
4. prints the package, service, user deployment, theme, greeter, verification,
   and reboot plan;
5. requires an exact trust-on-first-use confirmation containing the bundle ID
   and target user;
6. promotes the confirmed bytes to a versioned root-owned source bundle;
7. runs one privileged, bundle-verified orchestration;
8. prompts for reboot only after successful installed-state verification.

EOF, non-interactive input, an incorrect confirmation, or `n` cancels before
sudo. Reboot defaults to no.

## Trust-on-first-use promotion

The initial checkout is user-owned and is trusted only after the operator sees
the canonical source path, exact bundle ID, and fixed action plan and enters:

```text
INSTALL <64-character-bundle-id> AS <target-user>
```

The source bundle contains the installer runtime, five official package
manifests, fixed service/greeter policy, user deployment mappings and their
repository source closure, theme data, and required assets. Inputs are opened
without following symlinks, must be non-empty regular files, and are recorded
with fixed mode and SHA-256. The bundle ID is the SHA-256 of a canonical sorted
manifest.

Before trusted code exists, elevation may invoke only absolute host
`/usr/bin/install`, `/usr/bin/mkdir`, and `/usr/bin/mv` operations. Each copied
file is re-read from the root-owned staging tree and compared with the confirmed
manifest before publication. A changed source, unexpected file, unsafe path,
wrong owner/mode, or existing same-ID collision aborts without executing bundle
code. Published bundles live at:

```text
/opt/infinity-os/sources/<bundle-id>
```

Published bundles are retained for recovery and reproducibility. This proves
that privileged execution matches the locally confirmed bytes; it does not
prove publisher identity. Signed releases or package-manager bootstrap remain a
future stronger trust anchor.

## Privileged orchestration

The trusted bundle validates itself before creating one coherent installer log
at `/var/log/infinity-os/install.log`, then acquires a single-run lock and runs:

1. the fixed official package transaction;
2. live service activation for exactly `NetworkManager.service`,
   `bluetooth.service`, and `power-profiles-daemon.service`;
3. user-scoped deployment as the target user;
4. the deterministic `nocturne` theme as the target user;
5. transactional greetd/ReGreet deployment and next-boot enablement;
6. installed-state verification.

Package failure may leave successfully installed/upgraded packages. Service
failure may leave earlier curated services enabled and running. User deployment
retains its normal backups. Theme and greeter keep their existing rollback
contracts. Any failure stops later phases, reports recovery, and suppresses the
reboot prompt.

## Service and session policy

`NetworkManager`, Bluetooth, and power-profiles-daemon are enabled and started
with one fixed `/usr/bin/systemctl enable --now ...` invocation. No other system
service is force-enabled by the guided installer.

greetd is enabled for the next boot by its exact display-manager link but is not
started during installation, so the current VM session is not interrupted.
Hyprland is a graphical login session, not a system service. ReGreet discovers
the Arch-provided Hyprland desktop entry and keeps session selection visible
with `skip_selection = false`; after the first normal password login, ReGreet
remembers the selected Hyprland session per user. PipeWire, WirePlumber, portals,
Quickshell, and hypridle remain socket-, D-Bus-, or Hyprland-session activated.

The installer does not modify PAM, create autologin, or add authentication
mechanisms. Regular username/password authentication remains package-owned.

## Verification boundary

Repository tests use injected command runners and temporary roots; they never
invoke sudo, pacman, systemctl, or reboot. Installed-state verification checks
package presence, curated service enabled/active state, user deployment/theme
state, greeter files, the package-owned PAM file, Hyprland session discovery,
and the exact greetd display-manager link.

These checks still do not prove guest boot, graphics initialization, password
authentication, or Hyprland session handoff. Those claims require a disposable
QEMU run.
