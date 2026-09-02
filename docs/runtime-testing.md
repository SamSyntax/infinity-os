# Runtime testing

Infinity uses two test boundaries because a nested desktop and a virtual machine prove different things. **Nested Hyprland** gives a fast feedback loop for compositor configuration, Quickshell, themes, and workspaces. **QEMU** preserves the machine boundary needed for boot, system services, the greeter, authentication, and recovery.

Neither harness ever needs root.

## Nested Hyprland

Run the complete automated desktop smoke check from the repository root:

```sh
./launch-nested.sh --smoke
```

The launcher creates a unique run under `.runtime/nested/`, deploys repository-managed user files into that run's fake home, applies the initial theme there, and starts a separate D-Bus session and Hyprland process group. It clears the host Hyprland signature and stale NVIDIA driver-selection variables before launch. `INFINITY_TARGET_ROOT` makes Quickshell theme and wallpaper commits write back into the fake root instead of `/home/$USER`.

Hyprland's IPC socket path cannot fit beneath the repository's full absolute path. The launcher opens the repository runtime directory once and gives children the short stable path `/proc/<launcher-pid>/fd/<number>`. Qualifying the descriptor with the launcher's PID matters: D-Bus children may reuse the same descriptor number, while the launcher keeps its original directory descriptor open for the session. Hyprland, D-Bus, dconf, and Quickshell therefore create their runtime data under `.runtime/nested/`, and the harness creates no runtime alias outside the repository. For a relative `WAYLAND_DISPLAY`, the host Wayland socket is linked into the isolated runtime so the nested compositor can communicate bidirectionally with the host compositor; no host configuration file is changed.

Smoke mode verifies:

1. exactly one nested Hyprland signature and one sandbox Quickshell instance exist;
2. Hyprland reports no configuration errors and does not report `llvmpipe` or `softpipe`;
3. all Super+1…9 and Super+Shift+1…9 bindings are active;
4. a signature-qualified IPC action switches only the nested compositor to workspace 2;
5. applying a second theme changes the sandbox theme identity, Quickshell logs the in-memory reload, and neither Hyprland nor Quickshell exits;
6. the captured host workspace number and live theme file remain unchanged.

Success prints three `ok:` lines and exits 0. Failure names the failed assertion and retains the run directory. Relevant files include `hyprland.log`, `quickshell.log`, `systeminfo.txt`, `binds.json`, and the before/after theme hashes. The check proves desktop runtime behavior; it does not exercise hypridle, hyprlock authentication, greetd, or system services because those host-affecting integrations are deliberately disabled when `INFINITY_NESTED=1`. The navbar LOCK action is disabled so it cannot lock the host session, and network gateway probes are suppressed so nested visual checks do not generate host traffic.

For interactive inspection, run:

```sh
./launch-nested.sh
```

Close the nested window or press `Ctrl+C` in the launching terminal to stop its process group. Nested Quickshell deliberately runs without daemonizing, so the launcher can terminate the whole isolated process group. Cleanup records its result in `cleanup-status.txt`; an uncatchable `SIGKILL` can leave the ignored run directory but cannot leave a runtime alias outside the repository.

## QEMU

First check host acceleration without creating or booting a guest:

```sh
./bin/infinity-qemu-smoke --check
```

This reads `/dev/kvm`, the available DRM render node, and QEMU's device inventory. It writes nothing. Three `ok:` lines mean the current user can use KVM and QEMU provides a GL-capable virtio GPU.

Boot an explicit bootable qcow2 image in temporary snapshot mode:

```sh
./bin/infinity-qemu-smoke --image /path/to/infinity-test.qcow2
```

The command accepts only a standalone qcow2 image with no external backing or data file. It uses a Q35 machine, host CPU virtualization, four virtual CPUs, 4 GiB RAM, `virtio-gpu-gl`, GTK OpenGL display, virtio networking, and `-snapshot`. Snapshot mode directs disk changes to temporary QEMU state, so the source image is preserved. It also clears the stale NVIDIA GLX and VA-API variables before QEMU starts.

Each launch stores `guest-serial.log`, QEMU temporary files, and QEMU cache state under `.runtime/qemu/run.*`. Closing the VM window stops QEMU. A successful QEMU launch proves that KVM and virgl initialize; it does **not** prove that the guest booted, installed Infinity, reached ReGreet, authenticated, or locked securely. Those claims require a bootable qcow2 image plus a guest-side readiness marker and explicit test steps for boot, services, greeter, hyprlock, and recovery.

Nested mode isolates repository-managed configuration and runtime state; it is not a security sandbox for untrusted same-user applications. Programs launched inside it retain the invoking user's ordinary access unless a separate containment tool is added.

To inspect the exact command without starting QEMU:

```sh
./bin/infinity-qemu-smoke --image /path/to/infinity-test.qcow2 --dry-run
```
