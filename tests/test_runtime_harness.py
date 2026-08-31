#!/usr/bin/env python3
import subprocess
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def require_shell_syntax(path: Path) -> None:
    result = subprocess.run(
        ["/usr/bin/bash", "-n", str(path)],
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    require(result.returncode == 0, result.stdout)


def main() -> None:
    nested_path = REPO / "launch-nested.sh"
    nested = nested_path.read_text(encoding="utf-8")
    require(nested_path.stat().st_mode & 0o111, "nested launcher is not executable")
    require_shell_syntax(nested_path)
    require('RUNTIME_ROOT="$REPO_DIR/.runtime/nested"' in nested, "nested launcher state is not repository-local")
    require("/tmp/infinity-sandbox" not in nested, "nested launcher retains the shared /tmp sandbox")
    require('export INFINITY_TARGET_ROOT="$SANDBOX_ROOT"' in nested, "nested launcher does not scope theme writes to its sandbox")
    require('export INFINITY_NESTED="1"' in nested, "nested launcher does not identify its nested session")
    require("unset __GLX_VENDOR_LIBRARY_NAME" in nested, "nested launcher inherits the host GLX vendor override")
    require("unset LIBVA_DRIVER_NAME" in nested, "nested launcher inherits the host VA-API driver override")
    require("hyprctl dispatch workspace 5" not in nested, "nested launcher still changes the host workspace")
    require("hyprctl -i" in nested, "nested smoke commands are not qualified by instance signature")
    require('exec {RUNTIME_FD}<"$SANDBOX_RUNTIME_STORAGE"' in nested, "nested launcher lacks a repository-backed short IPC path")
    require('SANDBOX_RUNTIME_DIR="/proc/self/fd/$RUNTIME_FD"' in nested, "nested launcher does not use the inherited runtime descriptor")
    require("/run/user/$UID/.i" not in nested, "nested launcher writes a runtime alias outside the repository")
    require("llvmpipe" in nested and "softpipe" in nested, "nested smoke does not reject software rendering")
    require("theme-before.sha256" in nested and "theme-after.sha256" in nested, "nested smoke does not prove sandbox-only theme mutation")
    require('theme.get("themeId") == sys.argv[2]' in nested, "nested smoke does not validate the committed theme identity")

    theme = (REPO / "desktop/quickshell/services/Theme.qml").read_text(encoding="utf-8")
    wallpaper = (REPO / "desktop/quickshell/services/Wallpaper.qml").read_text(encoding="utf-8")
    require('readonly property string targetRoot: Quickshell.env("INFINITY_TARGET_ROOT") || "/"' in theme, "Theme service lacks an explicit target root")
    require('"--target-root", targetRoot' in theme, "Theme apply omits the explicit target root")
    require('console.info("Infinity theme loaded:", currentThemeId)' in theme, "Theme service lacks an observable reload signal")
    require('"--target-root", Theme.targetRoot' in wallpaper, "Wallpaper apply omits the explicit target root")

    autostart = (REPO / "desktop/hypr/modules/autostart.lua").read_text(encoding="utf-8")
    require('os.getenv("INFINITY_NESTED") == "1"' in autostart, "nested sessions lack an explicit autostart branch")
    nested_autostart = autostart.split("else", 1)[0]
    require("--daemonize" not in nested_autostart, "nested Quickshell escapes process-group supervision")

    bindings = (REPO / "desktop/hypr/modules/bindings.lua").read_text(encoding="utf-8")
    for expected in [
        "for workspace = 1, 9 do",
        'o.replace("ALT + " .. key, "Switch to workspace " .. key, hl.dsp.focus({ workspace = key }))',
        'o.replace("ALT + SHIFT + " .. key, "Move window to workspace " .. key, hl.dsp.window.move({ workspace = key }))',
    ]:
        require(expected in bindings, f"numeric workspace binding generator omitted {expected}")
    require('if os.getenv("INFINITY_NESTED") ~= "1" then' in bindings, "Quickshell toggle lacks a nested supervision guard")
    require('quickshell_start = quickshell_start .. " --daemonize"' in bindings, "production Quickshell toggle lost daemon mode")
    require('" .. quickshell_start)' in bindings, "Quickshell toggle does not use the supervised nested command")

    rail = (REPO / "desktop/quickshell/surfaces/RailSurface.qml").read_text(encoding="utf-8")
    require('readonly property bool nestedSession: Quickshell.env("INFINITY_NESTED") === "1"' in rail, "navbar lacks nested-session state")
    require("enabled: !root.nestedSession && !lockProcess.running" in rail, "nested navbar can invoke host session locking")

    qemu_path = REPO / "bin/infinity-qemu-smoke"
    require(qemu_path.is_file(), "QEMU smoke launcher is missing")
    require(qemu_path.stat().st_mode & 0o111, "QEMU smoke launcher is not executable")
    qemu = qemu_path.read_text(encoding="utf-8")
    require_shell_syntax(qemu_path)
    for expected in [
        "--image",
        "q35,accel=kvm",
        "virtio-gpu-gl",
        "gtk,gl=on",
        "-snapshot",
        "guest-serial.log",
        "__GLX_VENDOR_LIBRARY_NAME",
        "LIBVA_DRIVER_NAME",
        "DEVICE_HELP=$(qemu-system-x86_64 -device help 2>&1)",
        "QEMU_IMAGE=${IMAGE//,/,,}",
        'TMPDIR="$RUN_DIR/tmp"',
        "--check cannot be combined with --image",
        "--check cannot be combined with --dry-run",
        "image must be standalone; external backing or data file detected",
    ]:
        require(expected in qemu, f"QEMU smoke launcher omitted {expected}")
    require('RUNTIME_ROOT="$REPO_DIR/.runtime/qemu"' in qemu, "QEMU smoke state is not repository-local")
    require("qemu-monitor.sock" not in qemu, "QEMU smoke retains an unnecessary path-length-sensitive monitor socket")
    require(".runtime/" in (REPO / ".gitignore").read_text(encoding="utf-8").splitlines(), "runtime harness state is not ignored")

    mappings = (REPO / "deployment/mappings.tsv").read_text(encoding="utf-8")
    require("bin/infinity-capture-screenshot\t.local/bin/infinity-capture-screenshot\t0755\tno" in mappings, "screenshot binding command is not deployed")

    runtime_docs = (REPO / "docs/runtime-testing.md").read_text(encoding="utf-8")
    for expected in ["Nested Hyprland", "QEMU", "/proc/self/fd", "Neither harness ever needs root", "bootable qcow2"]:
        require(expected in runtime_docs, f"runtime testing documentation omitted {expected}")

    print("ok: isolated nested and accelerated QEMU harness contracts")


if __name__ == "__main__":
    main()
