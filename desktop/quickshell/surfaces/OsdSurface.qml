import Quickshell
import QtQuick
import "../components" as Components
import "../services" as Services

PanelWindow {
    id: root
    property bool shellVisible: true
    visible: shellVisible && (Services.ShellState.osdVisible || Quickshell.env("INFINITY_QA") === "osd")
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 286
    implicitHeight: 78
    anchors {
        right: true
        bottom: true
    }
    margins {
        right: 28
        bottom: 28
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.96)
        border.width: 1
        border.color: Services.Theme.border
        opacity: root.visible ? 1 : 0
        transform: Translate {
            y: root.visible ? 0 : 12
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Services.Theme.duration
            }
        }
        Behavior on transform {
            NumberAnimation {
                duration: Services.Theme.duration
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 9
            Row {
                width: parent.width
                Components.FolioLabel {
                    text: "OSD / " + Services.ShellState.osdLabel
                }
                Components.FolioLabel {
                    x: parent.width - width
                    text: Math.round(Services.ShellState.osdValue * 100).toString().padStart(2, "0")
                }
            }
            Rectangle {
                width: parent.width
                height: 12
                radius: 2
                color: Services.Theme.surfaceAlt
                Rectangle {
                    width: parent.width * Services.ShellState.osdValue
                    height: parent.height
                    radius: 2
                    color: Services.Theme.accent
                }
            }
        }
    }
}
