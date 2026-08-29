import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: root
                required property var modelData
                property bool reducedMotion: Quickshell.env("INFINITY_REDUCED_MOTION") === "1"
                property string dateText: Qt.formatDateTime(new Date(), "dddd, dd MMMM")
                readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "greeter"
                readonly property string wallpaperSource: Quickshell.env("INFINITY_GREETER_WALLPAPER") || "/usr/share/infinity-os/wallpapers/nocturne.svg"

                screen: modelData
                anchors { top: true; right: true; bottom: true; left: true }
                color: "#070914"
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                WlrLayershell.layer: qaVisible ? WlrLayer.Overlay : WlrLayer.Background

                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: root.dateText = Qt.formatDateTime(new Date(), "dddd, dd MMMM")
                }

                Image {
                    anchors.fill: parent
                    source: "file://" + root.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.82
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#070914"
                    opacity: 0.28
                }

                Rectangle {
                    id: orbitOuter
                    width: Math.min(parent.width, parent.height) * 0.68
                    height: width
                    anchors.centerIn: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#447ea6c9"
                    opacity: 0.62

                    RotationAnimation on rotation {
                        running: !root.reducedMotion
                        from: 0
                        to: 360
                        duration: 54000
                        loops: Animation.Infinite
                    }

                    Rectangle {
                        width: 7
                        height: 7
                        radius: width / 2
                        color: "#7ea6c9"
                        x: parent.width / 2 - width / 2
                        y: -height / 2
                    }
                }

                Rectangle {
                    width: orbitOuter.width * 0.62
                    height: width
                    anchors.centerIn: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#332a3550"

                    RotationAnimation on rotation {
                        running: !root.reducedMotion
                        from: 360
                        to: 0
                        duration: 38000
                        loops: Animation.Infinite
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 48
                    anchors.bottomMargin: 42
                    spacing: 6

                    Text { text: "INFINITY / ENTRY FIELD"; color: "#7ea6c9"; font.family: "IBM Plex Mono"; font.pixelSize: 11; font.letterSpacing: 2 }
                    Rectangle { width: 240; height: 1; color: "#2a3550" }
                    Text { text: root.dateText; color: "#eef4ff"; font.family: "IBM Plex Sans"; font.pixelSize: 15 }
                }
            }
        }
    }
}
