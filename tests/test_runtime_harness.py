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
    require('SANDBOX_RUNTIME_DIR="/proc/$$/fd/$RUNTIME_FD"' in nested, "nested launcher does not use a launcher-qualified runtime descriptor")
    require("/proc/self/fd" not in nested, "nested launcher exposes a child-relative runtime path to DBus services")
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
    require("effectiveWallpaperId" in wallpaper and "previewWallpaper.id" in wallpaper, "runtime wallpaper identity does not follow previews")

    autostart = (REPO / "desktop/hypr/modules/autostart.lua").read_text(encoding="utf-8")
    require('os.getenv("INFINITY_NESTED") == "1"' in autostart, "nested sessions lack an explicit autostart branch")
    nested_autostart = autostart.split("else", 1)[0]
    require("--daemonize" not in nested_autostart, "nested Quickshell escapes process-group supervision")

    bindings = (REPO / "desktop/hypr/modules/bindings.lua").read_text(encoding="utf-8")
    for expected in [
        "for workspace = 1, 9 do",
        'o.replace("SUPER + " .. key, "Switch to workspace " .. key, hl.dsp.focus({ workspace = key }))',
        'o.replace("SUPER + SHIFT + " .. key, "Move window to workspace " .. key, hl.dsp.window.move({ workspace = key }))',
        'o.replace("SUPER + CTRL + 4", "Master layout left"',
    ]:
        require(expected in bindings, f"numeric workspace binding generator omitted {expected}")
    require('o.replace("SUPER + 4", "Master layout left"' not in bindings, "Super+4 still overrides workspace selection")
    require('if os.getenv("INFINITY_NESTED") ~= "1" then' in bindings, "Quickshell toggle lacks a nested supervision guard")
    require('quickshell_start = quickshell_start .. " --daemonize"' in bindings, "production Quickshell toggle lost daemon mode")
    require('" .. quickshell_start)' in bindings, "Quickshell toggle does not use the supervised nested command")

    rail = (REPO / "desktop/quickshell/surfaces/RailSurface.qml").read_text(encoding="utf-8")
    require('readonly property bool nestedSession: Quickshell.env("INFINITY_NESTED") === "1"' in rail, "navbar lacks nested-session state")
    require("enabled: !root.nestedSession && !lockProcess.running" in rail, "nested navbar can invoke host session locking")
    require("onTapped: root.networkRequested()" in rail and "onTapped: root.calendarRequested()" in rail, "navbar network/calendar controls are not directly tappable")

    shell = (REPO / "desktop/quickshell/shell.qml").read_text(encoding="utf-8")
    for panel in ["network", "calendar"]:
        require(f'on{panel.title()}Requested: togglePanel("{panel}")' in shell, f"{panel} action bypasses the exclusive panel controller")
        require(f'activePanel === "{panel}"' in shell, f"{panel} surface lacks active-panel visibility")
    require(shell.count("onDismissRequested: closePanels()") >= 4, "new runtime panels do not share outside/Escape dismissal")

    workspaces = (REPO / "desktop/quickshell/services/Workspaces.qml").read_text(encoding="utf-8")
    activate = workspaces.split("function activate(workspaceId)", 1)[1].split("function specialActiveForScreen", 1)[0]
    require('Hyprland.dispatch("workspace " + workspaceId)' in activate and ".activate()" not in activate, "runtime workspace taps depend on tracked workspace objects")

    network = (REPO / "desktop/quickshell/services/Network.qml").read_text(encoding="utf-8")
    require('["/usr/bin/nmcli", "-g", "IP4.GATEWAY", "device", "show", gatewayRequestDevice]' in network, "runtime gateway lookup is not a fixed argv request")
    require('["/usr/bin/ping", "-n", "-q", "-c", "3", "-W", "1", pingRequestGateway]' in network, "runtime gateway probe is not a fixed argv request")
    require('readonly property bool probesAllowed: Quickshell.env("INFINITY_NESTED") !== "1"' in network, "nested runtime can probe the host network")
    require('readonly property var parserEnvironment: ({ LC_ALL: "C", LANG: "C" })' in network, "network process output is locale-dependent")
    require("function isValidDevice(candidate)" in network and "function isValidIpv4(candidate)" in network, "runtime network provider values are not validated")
    require("function requestRefresh()" in network and "function requestConnection(requestGeneration)" in network, "runtime network refresh stages are not sequenced")
    require("gatewayProcess.running || pingProcess.running" in network, "runtime network probes do not mutually exclude each other")
    require("gatewayRequestGeneration !== root.probeGeneration" in network and "requestGeneration !== probeGeneration" in network, "runtime network probes can publish stale generations")
    probe_timer = network.rsplit("Timer {", 1)[1]
    require("requestPing" not in probe_timer and "scheduleProbeCycle" in probe_timer, "runtime cadence launches overlapping probe stages")
    for public_target in ["1.1.1.1", "8.8.8.8", "google.com", "cloudflare.com"]:
        require(public_target not in network, f"runtime network service probes public target {public_target}")

    wallpaper_table = (REPO / "desktop/quickshell/components/WallpaperArchiveTable.qml").read_text(encoding="utf-8")
    require("!Services.ShellState.reducedMotion" in wallpaper_table, "wallpaper row motion ignores reduced-motion state")
    require("Services.ShellState.motionScale > 0" in wallpaper_table and "Services.Theme.duration > 0" in wallpaper_table, "wallpaper row motion ignores shared motion timing")
    require("onRunningChanged" in wallpaper_table and "rowDrift.x = 0" in wallpaper_table and "rowVisual.opacity = 1" in wallpaper_table, "wallpaper rows retain stale transforms when motion stops")
    wallpaper_surface = (REPO / "desktop/quickshell/surfaces/WallpaperSurface.qml").read_text(encoding="utf-8")
    require("status === Image.Ready" in wallpaper_surface and "wallpaperRequestGeneration" in wallpaper_surface, "runtime wallpaper crossfade activates before the replacement is ready")
    require("wallpaperMotionEnabled" in wallpaper_surface and "Services.ShellState.motionScale > 0" in wallpaper_surface, "runtime grain/scanline motion ignores zero motion scale")

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
    for expected in ["Nested Hyprland", "QEMU", "/proc/<launcher-pid>/fd", "Neither harness ever needs root", "bootable qcow2"]:
        require(expected in runtime_docs, f"runtime testing documentation omitted {expected}")

    print("ok: isolated nested and accelerated QEMU harness contracts")


if __name__ == "__main__":
    main()
