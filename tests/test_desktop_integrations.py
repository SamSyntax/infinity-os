#!/usr/bin/python3
import json
import os
import re
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


def config_blocks(config, name):
    return re.findall(rf"(?ms)^\s*{re.escape(name)}\s*\{{\s*(.*?)^\s*\}}", config)


def config_properties(block):
    return {
        line.split("=", 1)[0].strip()
        for line in block.splitlines()
        if "=" in line and not line.lstrip().startswith("#")
    }


def main():
    shell = (REPO / "desktop/quickshell/shell.qml").read_text(encoding="utf-8")
    for expected in ["activePanel", "togglePanel", 'activePanel === "appearance"', 'activePanel === "network"', 'activePanel === "calendar"', "specialWorkspaceActive", "shellVisible: !specialWorkspaceActive"]:
        require(expected in shell, f"shell panel controller omitted {expected}")

    for name in ["LauncherSurface.qml", "ControlSurface.qml", "NetworkSurface.qml", "CalendarSurface.qml"]:
        surface = (REPO / "desktop/quickshell/surfaces" / name).read_text(encoding="utf-8")
        require("panelVisible" in surface and "dismissRequested" in surface and "grabFocus" in surface, f"{name} lacks centralized dismissal wiring")

    launcher = (REPO / "desktop/quickshell/surfaces/LauncherSurface.qml").read_text(encoding="utf-8")
    for expected in [
        "Components.ArchiveBlackHole {",
        "id: accessionConnector",
        "Services.RailGeometry.outerGap",
        "anchorWindow.screen.width",
        "anchorWindow.screen.height",
        "anchor.rect.x: 0",
        "anchor.rect.y: Services.RailGeometry.surfaceHeight + Services.RailGeometry.outerGap",
        "Math.min(720, availableScreenWidth - Services.RailGeometry.outerGap * 2)",
        "NO MATCHING RECORDS",
        "INFINITY_QA_LAUNCHER_QUERY",
        "if (root.qaVisible)",
        "inkColor: Services.Theme.muted",
        "opacity: 0.76",
        "Filter local command records",
        "font.letterSpacing: root.microLetterSpacing",
        "font.pixelSize: root.microFontSize",
        '["/usr/bin/systemd-run", "--user", "--collect", "--quiet", "--", entry.command]',
        "Keys.onEscapePressed",
        "Keys.onReturnPressed",
        "Keys.onDownPressed",
        "Keys.onUpPressed",
        "onEntered: root.currentIndex = resultRow.index",
        "onClicked: root.activate(resultRow.index)",
        "enabled: !root.idle",
        "archiveBody.height - resultContentInset * 2",
        "elide: Text.ElideMiddle",
        "color: Services.Theme.surface",
        "maximumLineCount: 2",
        "textFormat: Text.PlainText",
        "wrapMode: Text.WordWrap",
    ]:
        require(expected in launcher, f"launcher archive redesign omitted {expected}")
    require("implicitWidth: 560" not in launcher and "implicitHeight: 430" not in launcher, "launcher retains fixed 560x430 geometry")
    require(launcher.count("Components.ArchiveBlackHole {") == 1, "launcher idle state must use one archive black hole")
    require("Components.EnergyConnector {" not in launcher, "launcher metadata connector must remain static")
    require('!root.hasMatches ? "TYPE TO REVISE QUERY"' in launcher, "launcher no-results footer suggests an unavailable action")

    appearance = (REPO / "desktop/quickshell/surfaces/AppearanceSurface.qml").read_text(encoding="utf-8")
    surface_module = (REPO / "desktop/quickshell/surfaces/qmldir").read_text(encoding="utf-8")
    require("AppearanceSurface 1.0 AppearanceSurface.qml" in surface_module, "appearance surface is not registered in the QML module")
    require("NetworkSurface 1.0 NetworkSurface.qml" in surface_module, "network surface is not registered in the QML module")
    require("CalendarSurface 1.0 CalendarSurface.qml" in surface_module, "calendar surface is not registered in the QML module")
    require("ThemeSurface 1.0" not in surface_module and "WallpaperPickerSurface 1.0" not in surface_module, "obsolete appearance surfaces remain registered")
    for expected in ["panelVisible", "dismissRequested", "WlrKeyboardFocus.Exclusive", "Services.Theme.preview", "Services.Wallpaper.preview", "function commit()", "function cancel()", "applyInFlight", "applyError", "DRAG STRIP", "onApplySucceeded"]:
        require(expected in appearance, f"appearance surface omitted {expected}")
    commit_body = appearance.split("function commit()", 1)[1].split("anchors {", 1)[0]
    require("dismissRequested" not in commit_body, "appearance chooser dismisses before apply succeeds")
    for expected in ["function syncSelection()", "Services.Theme.currentThemeId", "Services.Wallpaper.currentWallpaperId"]:
        require(expected in appearance, f"appearance selection synchronization omitted {expected}")
    open_body = appearance.split("onPanelVisibleChanged", 1)[1].split("Connections", 1)[0]
    require("selectedIndex = 0" not in open_body, "appearance chooser resets to the first theme when opened")
    responsive_tokens = [
        "readonly property bool compact:",
        "readonly property bool narrow:",
        "readonly property bool short:",
        "readonly property real outerGutter:",
        "readonly property real navigationWidth:",
        "readonly property real actionContentWidth:",
        "readonly property real filmstripHeight:",
        "readonly property real footerHeight:",
    ]
    for expected in responsive_tokens:
        require(expected in appearance, f"appearance responsive layout omitted {expected}")
    require("anchors.leftMargin: 220" not in appearance, "appearance preview or filmstrip retains the fixed 220px left inset")
    require("width: 150" not in appearance, "appearance action column retains a fixed 150px width")
    require("Math.max(76, Math.min(104" in appearance, "appearance navigation width is not bounded for narrow logical sizes")
    require("Math.max(104, Math.min(124" in appearance, "appearance action width is not bounded for narrow logical sizes")
    require("width: Math.max(0, Math.min(330" in appearance, "appearance preview metadata can overflow its image")
    for backplate in ["id: metadataBackplate", "id: actionBackplate"]:
        require(backplate in appearance, f"appearance text protection omitted {backplate}")

    rail = (REPO / "desktop/quickshell/surfaces/RailSurface.qml").read_text(encoding="utf-8")
    rail_button = (REPO / "desktop/quickshell/components/RailButton.qml").read_text(encoding="utf-8")
    rail_geometry = (REPO / "desktop/quickshell/services/RailGeometry.qml").read_text(encoding="utf-8")
    services_module = (REPO / "desktop/quickshell/services/qmldir").read_text(encoding="utf-8")
    for expected in ["infinity-navbar", "Services.Workspaces", "Services.Network.connected", "Services.Power.label", "Services.Time.clock", "signal networkRequested", "signal calendarRequested"]:
        require(expected in rail, f"navbar omitted {expected}")
    require("singleton RailGeometry 1.0 RailGeometry.qml" in services_module, "navbar geometry is not registered in the services module")
    for expected in [
        "readonly property int outerGap: 14",
        "readonly property int topGap: 6",
        "readonly property int surfaceHeight: 34",
        "readonly property int exclusiveZone: topGap + surfaceHeight",
        "readonly property int surfaceRadius: surfaceHeight / 4",
    ]:
        require(expected in rail_geometry, f"navbar shared geometry omitted {expected}")
    for expected in [
        "implicitHeight: Services.RailGeometry.surfaceHeight",
        "exclusiveZone: visible ? Services.RailGeometry.exclusiveZone : 0",
        "left: Services.RailGeometry.outerGap",
        "right: Services.RailGeometry.outerGap",
        "top: Services.RailGeometry.topGap",
    ]:
        require(expected in rail, f"navbar does not consume shared compact geometry: {expected}")
    require('property string layoutVariant: Quickshell.env("INFINITY_NAVBAR_LAYOUT") === "full" ? "full" : "islands"' in rail, "navbar does not default to islands with a repository-defined full-width switch")
    require("readonly property bool fullWidth: layoutVariant === \"full\"" in rail, "navbar full-width property switch is missing")
    require("id: fullSurface" in rail and "visible: root.fullWidth" in rail, "navbar full-width variant lacks an explicit visual surface")
    for island in ["id: leftIsland", "id: centerIsland", "id: rightIsland"]:
        require(island in rail, f"navbar split layout omitted {island}")
    require(rail.count("Components.RailButton {") == 4, "navbar must reuse RailButton exactly for OPEN, FIELD, STATE, and LOCK")
    for label in ['label: "OPEN"', 'label: "FIELD"', 'label: "STATE"', 'label: "LOCK"']:
        require(label in rail, f"navbar RailButton action omitted {label}")
    for action in ["root.launcherRequested()", "root.appearanceRequested()", "root.controlRequested()", 'command: ["/usr/bin/loginctl", "lock-session"]']:
        require(action in rail, f"navbar action wiring omitted {action}")
    for expected in ["implicitWidth:", "implicitHeight:", "Services.RailGeometry.controlHeight", "enabled: root.enabled"]:
        require(expected in rail_button, f"RailButton compact reusable geometry omitted {expected}")
    require("implicitWidth: childrenRect.width" not in rail, "navbar assigns the read-only Row.implicitWidth property")
    require("implicitHeight: Services.RailGeometry.controlHeight" not in rail, "navbar assigns the read-only Row.implicitHeight property")
    for expected in ["leftContent.childrenRect.width", "centerContent.childrenRect.width", "rightContent.childrenRect.width"]:
        require(expected in rail, f"navbar island width does not follow positioned content: {expected}")
    for expected in ["readonly property bool compact:", "readonly property bool narrow:", "visible: !root.narrow"]:
        require(expected in rail, f"navbar responsive visibility omitted {expected}")
    for expected in ["readonly property int compactBreakpoint: 1480", "readonly property int narrowBreakpoint: 1120"]:
        require(expected in rail_geometry, f"navbar responsive breakpoint changed: {expected}")
    right_island = rail.split("id: rightIsland", 1)[1]
    for expected in ["Services.Network.connected", "Services.Power.label", 'label: "STATE"', 'label: "LOCK"', "onTapped: root.networkRequested()"]:
        require(expected in right_island, f"navbar right island can drop required telemetry/action {expected}")
    for forbidden in ["Services.SystemResources.cpuLabel", "Services.SystemResources.memoryLabel", "Services.Network.label", "Services.Network.primaryName"]:
        require(forbidden not in right_island, f"navbar right island retains clutter: {forbidden}")
    require('model: [4, 8, 12]' in right_island and "rotation: 45" in right_island and "rotation: -45" in right_island, "navbar network control is not a purpose-built connected/offline geometric icon")
    center_island = rail.split("id: centerIsland", 1)[1].split("id: rightIsland", 1)[0]
    require("HoverHandler" in center_island and "TapHandler" in center_island and "onTapped: root.calendarRequested()" in center_island, "navbar clock/date is not a tactile calendar control")
    workspace_service = (REPO / "desktop/quickshell/services/Workspaces.qml").read_text(encoding="utf-8")
    activate_body = workspace_service.split("function activate(workspaceId)", 1)[1].split("function specialActiveForScreen", 1)[0]
    require('Hyprland.dispatch("workspace " + workspaceId)' in activate_body, "workspace activation omits direct Hyprland dispatch")
    require(".activate()" not in activate_body and "Hyprland.workspaces.values" not in activate_body, "workspace activation still depends on stale tracked objects")
    workspace_item = rail.split("id: workspaceItem", 1)[1].split("id: centerIsland", 1)[0]
    require("TapHandler" in workspace_item and "HoverHandler" in workspace_item and "workspaceTap.pressed" in workspace_item, "workspace item lacks full-area tap and feedback handlers")

    components_module = (REPO / "desktop/quickshell/components/qmldir").read_text(encoding="utf-8")
    energy_connector = (REPO / "desktop/quickshell/components/EnergyConnector.qml").read_text(encoding="utf-8")
    archive_black_hole = (REPO / "desktop/quickshell/components/ArchiveBlackHole.qml").read_text(encoding="utf-8")
    shader_dir = REPO / "desktop/quickshell/shaders"
    require("EnergyConnector 1.0 EnergyConnector.qml" in components_module, "energy connector is not registered in the component module")
    require("ArchiveBlackHole 1.0 ArchiveBlackHole.qml" in components_module, "archive black hole is not registered in the component module")
    require(rail.count("Components.EnergyConnector {") == 2, "split navbar must connect both island gaps")
    require(rail.index("Components.EnergyConnector {") < rail.index("id: leftIsland"), "navbar connectors must render behind the islands")
    require(rail.count("visible: !root.fullWidth && width > 0") == 2, "full-width navbar does not suppress both connectors")
    for forbidden in ["MouseArea", "TapHandler", "HoverHandler"]:
        require(forbidden not in energy_connector, f"energy connector intercepts input through {forbidden}")
    for expected in [
        "ShaderEffect {",
        'fragmentShader: Qt.resolvedUrl("../shaders/energy_connector.frag.qsb")',
        "shader.status === ShaderEffect.Compiled",
        "shader.log",
        "softwareBackend",
        "Screen.devicePixelRatio",
        "property size logicalSize",
        "visible: root.reducedMotion || !root.shaderReady",
        "running: !root.reducedMotion && root.shaderReady",
    ]:
        require(expected in energy_connector, f"energy connector omitted {expected}")
    for expected in [
        "ShaderEffect {",
        'fragmentShader: Qt.resolvedUrl("../shaders/archive_black_hole.frag.qsb")',
        "shader.status === ShaderEffect.Compiled",
        "shader.log",
        "softwareBackend",
        "Screen.devicePixelRatio",
        "visible: root.reducedMotion || !root.shaderReady",
        "running: !root.reducedMotion && root.shaderReady",
    ]:
        require(expected in archive_black_hole, f"archive black hole omitted {expected}")
    require("Image {" not in archive_black_hole and "Canvas {" not in archive_black_hole, "archive black hole depends on an image or Canvas asset")
    for shader_name in ["energy_connector.frag", "archive_black_hole.frag"]:
        source_path = shader_dir / shader_name
        compiled_path = shader_dir / f"{shader_name}.qsb"
        require(source_path.is_file(), f"shader source is missing: {shader_name}")
        require(compiled_path.is_file() and compiled_path.stat().st_size > 0, f"compiled shader is missing: {shader_name}.qsb")
        source = source_path.read_text(encoding="utf-8")
        for expected in ["#version 440", "qt_TexCoord0", "layout(std140, binding = 0) uniform buf", "mat4 qt_Matrix", "float qt_Opacity", "logicalSize", "devicePixelRatio"]:
            require(expected in source, f"{shader_name} omitted Qt 6 shader contract token {expected}")
        qsb = Path("/usr/lib/qt6/bin/qsb")
        require(qsb.is_file(), "Qt Shader Tools qsb is required to validate compiled shader metadata")
        reflection = run([str(qsb), "-d", str(compiled_path)]).stdout
        for expected in ["Stage: Fragment", '"binding": 0', '"name": "qt_Matrix"', '"name": "qt_Opacity"', '"name": "logicalSize"', '"name": "devicePixelRatio"']:
            require(expected in reflection, f"{shader_name}.qsb reflection omitted {expected}")
    black_hole_shader = (shader_dir / "archive_black_hole.frag").read_text(encoding="utf-8")
    for expected in ["accretion", "lensedArc", "horizon", "hash21", "dithered", "edgeFade"]:
        require(expected in black_hole_shader, f"procedural black-hole shader omitted {expected}")

    service_commands = {
        "Workspaces.qml": ["Quickshell.Hyprland", "specialActiveForScreen"],
        "SystemResources.qml": ['"/proc/stat"', '"/proc/meminfo"'],
        "Network.qml": ['"/usr/bin/nmcli"', '"/usr/bin/ping"', "NET --"],
        "Power.qml": ['"/usr/bin/upower"', "PWR --"],
        "Audio.qml": ['"/usr/bin/wpctl"', '"get-volume"', "queuedLevel"],
    }
    for name, expected_values in service_commands.items():
        service = (REPO / "desktop/quickshell/services" / name).read_text(encoding="utf-8")
        for expected in expected_values:
            require(expected in service, f"{name} omitted {expected}")

    network_service = (REPO / "desktop/quickshell/services/Network.qml").read_text(encoding="utf-8")
    for expected in [
        'property string device: ""',
        'property string transferState: "unavailable"',
        'property string gatewayState: "unavailable"',
        'property string packetLossState: "unavailable"',
        'property string latencyState: "unavailable"',
        'readonly property bool probesAllowed: Quickshell.env("INFINITY_NESTED") !== "1"',
        'readonly property var parserEnvironment: ({ LC_ALL: "C", LANG: "C" })',
        "property int refreshGeneration: 0",
        "property int generalRequestGeneration: -1",
        "property int connectionRequestGeneration: -1",
        "function isValidDevice(candidate)",
        "function isValidIpv4(candidate)",
        "function requestRefresh()",
        "function requestConnection(requestGeneration)",
        '"/sys/class/net/" + root.device + "/statistics/rx_bytes"',
        '"/sys/class/net/" + root.device + "/statistics/tx_bytes"',
        '["/usr/bin/nmcli", "-g", "IP4.GATEWAY", "device", "show", gatewayRequestDevice]',
        '["/usr/bin/ping", "-n", "-q", "-c", "3", "-W", "1", pingRequestGateway]',
        "gatewayProcess.running || pingProcess.running",
        "requestGeneration !== probeGeneration",
        "gatewayRequestGeneration !== root.probeGeneration",
        "pingRequestGeneration",
        'candidate === "connected (site only)"',
        "if (!connected)",
        "onTriggered: root.scheduleProbeCycle()",
        'interval: 15000',
    ]:
        require(expected in network_service, f"network telemetry contract omitted {expected}")
    require(network_service.count("environment: root.parserEnvironment") == 4, "network parser processes do not share a locale-stable environment")
    discovery_processes = network_service.split("id: generalProcess", 1)[1].split("id: gatewayProcess", 1)[0]
    require("running: true" not in discovery_processes, "network general and connection discovery still race at startup")
    require("root.requestConnection(requestGeneration)" in network_service, "network connection discovery is not sequenced after general state")
    require("requestGeneration !== root.refreshGeneration" in network_service, "network refresh callbacks can publish stale state")
    require("!root.probesAllowed" in network_service, "nested sessions can still generate gateway probe traffic")
    require("root.isValidDevice(root.device)" in network_service, "sysfs transfer sampling accepts an unsafe interface name")
    require("!isValidIpv4(nextGateway)" in network_service, "gateway probing accepts a non-IPv4 target")
    require("preload: false" in network_service and "reload()" in network_service and "waitForJob()" in network_service, "network counter sampling lost the documented explicit FileView reload path")
    probe_timer = network_service.rsplit("Timer {", 1)[1]
    require("requestPing" not in probe_timer, "network cadence timer can overlap gateway discovery and ping")
    for forbidden in ["1.1.1.1", "8.8.8.8", "google.com", "cloudflare.com", "sh -c", "bash -c"]:
        require(forbidden not in network_service, f"network service contains a public or shell-string probe: {forbidden}")

    network_surface = (REPO / "desktop/quickshell/surfaces/NetworkSurface.qml").read_text(encoding="utf-8")
    for expected in ["Services.Network.primaryName", "Services.Network.primaryType", "Services.Network.device", "Services.Network.connectivity", "Services.Network.downBytesPerSecond", "Services.Network.upBytesPerSecond", "Services.Network.packetLossPercent", "Services.Network.averageLatencyMs", 'return "MEASURING"', 'return "UNAVAILABLE"']:
        require(expected in network_surface, f"network surface omitted truthful detail {expected}")
    require(not re.search(r'\b(?:42|64|100)\s*(?:ms|MiB/s|KiB/s|%)', network_surface), "network surface contains a hardcoded fake metric")

    calendar_surface = (REPO / "desktop/quickshell/surfaces/CalendarSurface.qml").read_text(encoding="utf-8")
    for expected in ["new Date()", "new Date(year, month, 1)", "new Date(year, month + 1, 0)", "(new Date(year, month, 1).getDay() + 6) % 7", "cell < 42", '["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]', "onPanelVisibleChanged", "resetMonth()", "modelData.today", 'label: "PREV", offset: -1', 'label: "NEXT", offset: 1', "root.changeMonth(monthControl.modelData.offset)"]:
        require(expected in calendar_surface, f"calendar surface omitted {expected}")
    require("Process {" not in calendar_surface and "Quickshell.Io" not in calendar_surface, "calendar math depends on an external provider")

    wallpaper_surface = (REPO / "desktop/quickshell/surfaces/WallpaperSurface.qml").read_text(encoding="utf-8")
    wallpaper_table = (REPO / "desktop/quickshell/components/WallpaperArchiveTable.qml").read_text(encoding="utf-8")
    for expected in ["previewPath", "Canvas", "grainFrame", "reducedMotion", "NumberAnimation on y"]:
        require(expected in wallpaper_surface, f"animated wallpaper omitted {expected}")
    require(wallpaper_surface.count("Components.WallpaperArchiveTable {") == 2, "wallpaper crossfade does not pair both images with archival overlays")
    require("Services.Wallpaper.effectiveWallpaperId" in wallpaper_surface, "wallpaper overlay ignores preview identity")
    for expected in ["wallpaperRequestGeneration", "primaryPendingSource", "secondaryPendingSource", "status === Image.Ready", "root.activatePrimary()", "root.activateSecondary()", "onCurrentWallpaperIdChanged", "root.wallpaperMotionEnabled", "Services.ShellState.motionScale > 0"]:
        require(expected in wallpaper_surface, f"wallpaper readiness/motion contract omitted {expected}")
    require("WallpaperArchiveTable 1.0 WallpaperArchiveTable.qml" in components_module, "wallpaper archive table is not registered")
    for wallpaper_id in ["aurora", "cobalt-relay", "ember-index", "nocturne", "signal-archive", "verdigris-ledger"]:
        require(f'"{wallpaper_id}"' in wallpaper_table, f"wallpaper overlay omitted mapping {wallpaper_id}")
    for expected in ["HEAT", "642 K", "HALFTONE / DISPLACE", "41.82 KHZ", "cropScale: Math.max(width / 1600, height / 900)", "cropOffsetX", "cropOffsetY", "Translate {", 'property: "opacity"', "root.opacity > 0", "!Services.ShellState.reducedMotion", "Services.ShellState.motionScale > 0", "Services.Theme.duration > 0", "onRunningChanged"]:
        require(expected in wallpaper_table, f"wallpaper archival animation omitted {expected}")
    require("NumberAnimation on x" not in wallpaper_table and "NumberAnimation on y" not in wallpaper_table, "wallpaper rows animate layout coordinates instead of transforms")

    theme_service = (REPO / "desktop/quickshell/services/Theme.qml").read_text(encoding="utf-8")
    wallpaper_service = (REPO / "desktop/quickshell/services/Wallpaper.qml").read_text(encoding="utf-8")
    control_surface = (REPO / "desktop/quickshell/surfaces/ControlSurface.qml").read_text(encoding="utf-8")
    require("Services.Audio.outputLevel" in control_surface and "0.64" not in control_surface, "control surface volume is not live telemetry")
    require("previewTheme = null" in theme_service and "pendingThemeId = \"\"" in theme_service, "theme failure does not clear preview transaction state")
    require("root.clearPreview()" in wallpaper_service and "pendingWallpaperId = \"\"" in wallpaper_service, "wallpaper failure does not clear preview transaction state")
    require("readonly property string effectiveWallpaperId: previewWallpaper === null ? currentWallpaperId : previewWallpaper.id" in wallpaper_service, "wallpaper service lacks preview-aware effective identity")
    apply_process = wallpaper_service.split("id: applyProcess", 1)[1]
    apply_success = apply_process.split("if (exitCode === 0)", 1)[1].split("} else", 1)[0]
    require(apply_success.index("stateAdapter.wallpaperId = appliedWallpaperId") < apply_success.index("root.clearPreview()"), "wallpaper apply clears preview before committed identity is authoritative")

    require('"apply", themeId' in theme_service and '"list", "--json"' in theme_service, "theme UI lacks catalog/apply commands")
    require('"wallpaper", wallpaperId' in wallpaper_service and '"wallpapers", "--json"' in wallpaper_service, "wallpaper UI lacks catalog/apply commands")

    greetd = (REPO / "system/services/greetd.toml").read_text(encoding="utf-8")
    greeter = (REPO / "desktop/greeter/start-greeter").read_text(encoding="utf-8")
    lock = (REPO / "desktop/lockscreen/hyprlock.conf").read_text(encoding="utf-8")
    require("start-greeter" in greetd and "regreet" in greeter and "quickshell" in greeter, "greeter must retain ReGreet authentication with a Quickshell visual layer")
    require("source = ~/.config/hypr/generated-lock.conf" in lock and "animations" in lock, "hyprlock lacks generated tokens or supported animations")
    require("immediate_render = true" in lock, "hyprlock must render immediately")
    require("path = ~/.local/share/infinity-os/current-wallpaper.svg" in lock, "hyprlock omitted the generated wallpaper path")

    shape_allowlist = {
        "monitor", "size", "rounding", "border_size", "border_color", "color",
        "position", "halign", "valign", "rotate", "xray", "zindex",
        "shadow_size", "shadow_passes", "shadow_color", "shadow_boost",
    }
    shapes = config_blocks(lock, "shape")
    require(len(shapes) >= 10, "split folio needs four plates, two seams, and four register marks")
    for shape in shapes:
        unsupported = config_properties(shape) - shape_allowlist
        require(not unsupported, f"hyprlock shape uses unsupported properties: {sorted(unsupported)}")
        require("zindex" in config_properties(shape), "hyprlock shape lacks explicit stacking order")
    require(sum("size = 150, 64" in shape for shape in shapes) == 4, "split folio must have four balanced 150x64 half-plates")
    require(sum("size = 138, 2" in shape for shape in shapes) == 2, "split folio must expose one center seam per folio")
    require(sum("size = 5, 12" in shape for shape in shapes) == 4, "split folio must include four subtle register marks")

    labels = config_blocks(lock, "label")
    label_allowlist = {
        "monitor", "text", "color", "font_size", "font_family", "position",
        "halign", "valign", "rotate", "shadow_passes", "shadow_size",
        "shadow_color", "shadow_boost", "zindex",
    }
    for label in labels:
        unsupported = config_properties(label) - label_allowlist
        require(not unsupported, f"hyprlock label uses unsupported properties: {sorted(unsupported)}")
    hour_command = "cmd[update:1000] /usr/bin/date '+%H'"
    minute_command = "cmd[update:1000] /usr/bin/date '+%M'"
    archive_date_command = "cmd[update:60000] /usr/bin/date '+%A, %d %B %Y'"
    require(lock.count(f"text = {hour_command}") == 1, "hours folio must use the fixed absolute date command")
    require(lock.count(f"text = {minute_command}") == 1, "minutes folio must use the fixed absolute date command")
    require(lock.count(f"text = {archive_date_command}") == 1, "archive date must use the fixed absolute date command")
    dynamic_commands = re.findall(r"(?m)^\s*text\s*=\s*(cmd\[[^\n]+)$", lock)
    require(set(dynamic_commands) == {hour_command, minute_command, archive_date_command}, "hyprlock labels invoke an arbitrary command")
    for expected in ["HOURS", "MINUTES", "TEMPORAL ARCHIVE", "SESSION SECURED"]:
        require(expected in lock, f"hyprlock archive hierarchy omitted {expected}")

    for token in [
        "$infinityLockBackground", "$infinityLockText", "$infinityLockSurface",
        "$infinityLockBorder", "$infinityLockAccent", "$infinityLockError",
    ]:
        require(token in lock, f"hyprlock omitted generated token {token}")
    require("check_color = $infinityLockAccent" in lock and "fail_color = $infinityLockError" in lock, "hyprlock lost generated check/fail states")
    require("zindex = 20" in lock, "hyprlock labels/input must stack above folio shapes")

    animation_allowlist = {
        "global", "fade", "fadeIn", "fadeOut", "inputField", "inputFieldColors",
        "inputFieldFade", "inputFieldWidth", "inputFieldDots",
    }
    animation_blocks = config_blocks(lock, "animations")
    require(len(animation_blocks) == 1, "hyprlock must define one animation tree")
    animation_nodes = {
        line.split("=", 1)[1].split(",", 1)[0].strip()
        for line in animation_blocks[0].splitlines()
        if line.strip().startswith("animation =")
    }
    require(animation_nodes <= animation_allowlist, f"hyprlock uses unsupported animation nodes: {sorted(animation_nodes - animation_allowlist)}")
    require({"fadeIn", "fadeOut", "inputFieldColors", "inputFieldDots", "inputFieldWidth"} <= animation_nodes, "hyprlock lost its supported startup/input animation tree")
    require("onclick" not in lock.lower(), "hyprlock must not expose clickable command actions")

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
