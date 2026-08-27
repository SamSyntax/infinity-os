pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property color background: adapter.palette.background
    readonly property color surface: adapter.palette.surface
    readonly property color surfaceAlt: adapter.palette.surfaceAlt
    readonly property color text: adapter.palette.text
    readonly property color muted: adapter.palette.muted
    readonly property color accent: adapter.palette.accent
    readonly property color border: adapter.palette.border
    readonly property color success: adapter.palette.success
    readonly property color warning: adapter.palette.warning
    readonly property color error: adapter.palette.error
    readonly property int radius: adapter.radius
    readonly property int duration: ShellState.reducedMotion ? 0 : adapter.durationMs
    readonly property real panelOpacity: adapter.opacity
    readonly property string fontFamily: "IBM Plex Sans"
    readonly property string displayFamily: "IBM Plex Serif"
    readonly property string monoFamily: "IBM Plex Mono"

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/generated/theme.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
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
