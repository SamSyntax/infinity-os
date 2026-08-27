import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components" as Components
import "../services" as Services

PanelWindow {
    id: root
    signal controlRequested
    signal launcherRequested
    signal themesRequested
    color: "transparent"
    implicitWidth: 66
    exclusiveZone: 76
    WlrLayershell.namespace: "infinity-rail"
    anchors { top: true; bottom: true; left: true }
    margins { top: 10; bottom: 10; left: 10 }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, Services.Theme.panelOpacity)
        border.width: 1
        border.color: Services.Theme.border

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            spacing: 4

            Item {
                width: 48; height: 58
                Text {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 7
                    text: "∞"; color: Services.Theme.accent; font.family: Services.Theme.fontFamily; font.pixelSize: 22
                }
                Components.FolioLabel { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 7; text: "INDEX" }
            }
            Rectangle { width: 48; height: 1; color: Services.Theme.border }
            Components.RailButton { index: "01"; label: "OPEN"; onClicked: root.launcherRequested() }
            Components.RailButton { index: "02"; label: "STATE"; onClicked: root.controlRequested() }
            Components.RailButton { index: "03"; label: "THEME"; onClicked: root.themesRequested() }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Services.Time.clock; color: Services.Theme.text; font.family: Services.Theme.monoFamily; font.pixelSize: 11 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Services.Time.date.slice(4); color: Services.Theme.muted; font.family: Services.Theme.monoFamily; font.pixelSize: 8 }
        }
    }
}
