pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var catalog: []
    property var previewTheme: null
    property bool applying: false
    property string applyError: ""
    property string pendingThemeId: ""
    readonly property string commandPath: Quickshell.env("INFINITY_THEME_COMMAND") || Quickshell.env("HOME") + "/.local/share/infinity-os/runtime/bin/infinity-theme"
    readonly property var activePalette: previewTheme === null ? adapter.palette : previewTheme.palette
    readonly property string currentThemeId: adapter.themeId
    readonly property string previewThemeId: previewTheme === null ? "" : previewTheme.id
    readonly property color background: activePalette.background
    readonly property color surface: activePalette.surface
    readonly property color surfaceAlt: activePalette.surfaceAlt
    readonly property color text: activePalette.text
    readonly property color muted: activePalette.muted
    readonly property color accent: activePalette.accent
    readonly property color border: activePalette.border
    readonly property color success: activePalette.success
    readonly property color warning: activePalette.warning
    readonly property color error: activePalette.error
    readonly property int radius: adapter.radius
    readonly property int duration: ShellState.reducedMotion ? 0 : Math.round(adapter.durationMs * ShellState.motionScale)
    readonly property real panelOpacity: adapter.opacity
    readonly property string fontFamily: "IBM Plex Sans"
    readonly property string displayFamily: "IBM Plex Serif"
    readonly property string monoFamily: "IBM Plex Mono"

    signal applySucceeded(string themeId)

    function preview(theme) {
        previewTheme = theme;
        applyError = "";
    }

    function clearPreview() {
        previewTheme = null;
    }

    function apply(themeId) {
        if (applying || themeId.length === 0)
            return;
        pendingThemeId = themeId;
        applyError = "";
        applying = true;
        applyProcess.command = [commandPath, "apply", themeId, "--target-user", Quickshell.env("USER")];
        applyProcess.running = true;
    }

    Process {
        id: catalogProcess
        command: [root.commandPath, "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.catalog = JSON.parse(text);
                } catch (error) {
                    root.applyError = "Theme catalog is invalid: " + error;
                }
            }
        }
        stderr: StdioCollector {
            id: catalogError
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.applyError = catalogError.text.trim() || "Unable to load theme catalog";
        }
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            id: applyOutput
        }
        stderr: StdioCollector {
            id: applyFailure
        }
        onExited: (exitCode, exitStatus) => {
            root.applying = false;
            if (exitCode === 0) {
                root.previewTheme = null;
                const appliedThemeId = root.pendingThemeId;
                root.pendingThemeId = "";
                root.applySucceeded(appliedThemeId);
            } else {
                root.previewTheme = null;
                root.pendingThemeId = "";
                root.applyError = applyFailure.text.trim() || applyOutput.text.trim() || "Theme apply failed";
            }
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/generated/theme.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string themeId: "nocturne"
            property string name: "Nocturne Index"
            property string mode: "dark"
            property int radius: 14
            property real opacity: 0.9
            property int durationMs: 180
            property JsonObject palette: JsonObject {
                property string background: "#0b0f14"
                property string surface: "#141a21"
                property string surfaceAlt: "#1d2630"
                property string text: "#edf1f5"
                property string muted: "#8995a3"
                property string accent: "#7ea6c9"
                property string border: "#2c3742"
                property string success: "#83b99a"
                property string warning: "#d0aa6d"
                property string error: "#cf7f83"
            }
        }
    }
}
