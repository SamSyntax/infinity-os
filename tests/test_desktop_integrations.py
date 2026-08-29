#!/usr/bin/python3
import json
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def run(command, *, env=None):
    result = subprocess.run(
        command,
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=os.environ | {"PYTHONDONTWRITEBYTECODE": "1"} | (env or {}),
    )
    require(result.returncode == 0, result.stdout + result.stderr)
    return result


def main():
    shell = (REPO / "desktop/quickshell/shell.qml").read_text(encoding="utf-8")
    for expected in ["activePanel", "togglePanel", 'activePanel === "appearance"', "specialWorkspaceActive", "shellVisible: !specialWorkspaceActive"]:
        require(expected in shell, f"shell panel controller omitted {expected}")

    for name in ["LauncherSurface.qml", "ControlSurface.qml"]:
        surface = (REPO / "desktop/quickshell/surfaces" / name).read_text(encoding="utf-8")
        require("panelVisible" in surface and "dismissRequested" in surface and "grabFocus" in surface, f"{name} lacks centralized dismissal wiring")

    appearance = (REPO / "desktop/quickshell/surfaces/AppearanceSurface.qml").read_text(encoding="utf-8")
    surface_module = (REPO / "desktop/quickshell/surfaces/qmldir").read_text(encoding="utf-8")
    require("AppearanceSurface 1.0 AppearanceSurface.qml" in surface_module, "appearance surface is not registered in the QML module")
    require("ThemeSurface 1.0" not in surface_module and "WallpaperPickerSurface 1.0" not in surface_module, "obsolete appearance surfaces remain registered")
    for expected in ["panelVisible", "dismissRequested", "WlrKeyboardFocus.Exclusive", "Services.Theme.preview", "Services.Wallpaper.preview", "function commit()", "function cancel()", "applyInFlight", "applyError", "DRAG STRIP", "onApplySucceeded"]:
        require(expected in appearance, f"appearance surface omitted {expected}")
    commit_body = appearance.split("function commit()", 1)[1].split("anchors {", 1)[0]
    require("dismissRequested" not in commit_body, "appearance chooser dismisses before apply succeeds")

    rail = (REPO / "desktop/quickshell/surfaces/RailSurface.qml").read_text(encoding="utf-8")
    for expected in ["infinity-navbar", "Services.Workspaces", "Services.SystemResources.cpuLabel", "Services.Network.label", "Services.Power.label", "Services.Time.clock"]:
        require(expected in rail, f"navbar omitted {expected}")

    service_commands = {
        "Workspaces.qml": ["Quickshell.Hyprland", "specialActiveForScreen"],
        "SystemResources.qml": ['"/proc/stat"', '"/proc/meminfo"'],
        "Network.qml": ['"/usr/bin/nmcli"', "NET --"],
        "Power.qml": ['"/usr/bin/upower"', "PWR --"],
        "Audio.qml": ['"/usr/bin/wpctl"', '"get-volume"', "queuedLevel"],
    }
    for name, expected_values in service_commands.items():
        service = (REPO / "desktop/quickshell/services" / name).read_text(encoding="utf-8")
        for expected in expected_values:
            require(expected in service, f"{name} omitted {expected}")

    wallpaper_surface = (REPO / "desktop/quickshell/surfaces/WallpaperSurface.qml").read_text(encoding="utf-8")
    for expected in ["previewPath", "Canvas", "grainFrame", "reducedMotion", "NumberAnimation on y"]:
        require(expected in wallpaper_surface, f"animated wallpaper omitted {expected}")

    theme_service = (REPO / "desktop/quickshell/services/Theme.qml").read_text(encoding="utf-8")
    wallpaper_service = (REPO / "desktop/quickshell/services/Wallpaper.qml").read_text(encoding="utf-8")
    control_surface = (REPO / "desktop/quickshell/surfaces/ControlSurface.qml").read_text(encoding="utf-8")
    require("Services.Audio.outputLevel" in control_surface and "0.64" not in control_surface, "control surface volume is not live telemetry")
    require("previewTheme = null" in theme_service and "pendingThemeId = \"\"" in theme_service, "theme failure does not clear preview transaction state")
    require("root.clearPreview()" in wallpaper_service and "pendingWallpaperId = \"\"" in wallpaper_service, "wallpaper failure does not clear preview transaction state")

    require('"apply", themeId' in theme_service and '"list", "--json"' in theme_service, "theme UI lacks catalog/apply commands")
    require('"wallpaper", wallpaperId' in wallpaper_service and '"wallpapers", "--json"' in wallpaper_service, "wallpaper UI lacks catalog/apply commands")

    greetd = (REPO / "system/services/greetd.toml").read_text(encoding="utf-8")
    greeter = (REPO / "desktop/greeter/start-greeter").read_text(encoding="utf-8")
    lock = (REPO / "desktop/lockscreen/hyprlock.conf").read_text(encoding="utf-8")
    require("start-greeter" in greetd and "regreet" in greeter and "quickshell" in greeter, "greeter must retain ReGreet authentication with a Quickshell visual layer")
    require("source = ~/.config/hypr/generated-lock.conf" in lock and "animations" in lock, "hyprlock lacks generated tokens or supported animations")

    with tempfile.TemporaryDirectory(prefix="infinity-desktop-integration-") as tmp:
        root = Path(tmp)
        passwd = root / "etc/passwd"
        passwd.parent.mkdir()
        passwd.write_text(f"testuser:x:{os.geteuid()}:{os.getegid()}:Test User:/home/testuser:/bin/bash\n", encoding="utf-8")

        run([sys.executable, str(REPO / "bin/infinity-deploy"), "--scope", "user", "--target-root", str(root), "--target-user", "testuser"])
        runtime_cli = root / "home/testuser/.local/share/infinity-os/runtime/bin/infinity-theme"
        require(runtime_cli.is_file() and os.access(runtime_cli, os.X_OK), "runtime theme CLI was not deployed executable")

        catalog = json.loads(run([str(runtime_cli), "list", "--json"]).stdout)
        expected_ids = {
            path.stem
            for path in (REPO / "desktop/themes").glob("*.json")
            if path.name != "schema.json"
        }
        require({item["id"] for item in catalog} == expected_ids, "runtime theme catalog is incomplete")

        wallpapers = json.loads(run([str(runtime_cli), "wallpapers", "--json"]).stdout)
        require({item["id"] for item in wallpapers} == expected_ids, "runtime wallpaper catalog is incomplete")
        for wallpaper in wallpapers:
            ET.parse(REPO / wallpaper["path"])

        run([str(runtime_cli), "apply", "aurora", "--target-root", str(root), "--target-user", "testuser"])
        home = root / "home/testuser"
        generated = json.loads((home / ".config/quickshell/generated/theme.json").read_text(encoding="utf-8"))
        require(generated["themeId"] == "aurora", "theme apply did not persist generated theme identity")
        require((home / ".config/hypr/generated-lock.conf").is_file(), "theme apply omitted lockscreen tokens")

        run([str(runtime_cli), "wallpaper", "signal-archive", "--target-root", str(root), "--target-user", "testuser"])
        wallpaper_state = json.loads((home / ".local/share/infinity-os/wallpaper.json").read_text(encoding="utf-8"))
        require(wallpaper_state["wallpaperId"] == "signal-archive", "wallpaper apply did not persist selection")
        require((home / ".local/share/infinity-os/current-theme").read_text(encoding="utf-8") == "aurora\n", "wallpaper apply changed the active theme")

    print("ok: live navbar, unified appearance, animated wallpaper, runtime transactions, greeter, and secure lock integration")


if __name__ == "__main__":
    main()
