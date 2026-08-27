import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root
    required property var anchorWindow
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width + 18
    anchor.rect.y: 22
    implicitWidth: 340
    implicitHeight: 410
    visible: Quickshell.env("INFINITY_QA") === "control"
    color: "transparent"
    grabFocus: true

    Rectangle {
        anchors.fill: parent
        radius: Services.Theme.radius
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.96)
        border.width: 1
        border.color: Services.Theme.border
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.97
        transformOrigin: Item.TopLeft
        Behavior on opacity { NumberAnimation { duration: Services.Theme.duration } }
        Behavior on scale { NumberAnimation { duration: Services.Theme.duration; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            Components.FolioLabel { text: "02 / SYSTEM STATE" }
            Text { text: "Quiet machinery"; color: Services.Theme.text; font.family: Services.Theme.fontFamily; font.pixelSize: 25; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; text: "The essential controls stay close. Detail appears only when requested."; color: Services.Theme.muted; font.family: Services.Theme.fontFamily; font.pixelSize: 12; wrapMode: Text.WordWrap }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Services.Theme.border }
            Components.StatusRow { Layout.fillWidth: true; label: "NETWORK"; value: "READY"; valueColor: Services.Theme.success }
            Components.StatusRow { Layout.fillWidth: true; label: "BLUETOOTH"; value: "IDLE"; valueColor: Services.Theme.muted }
            Components.StatusRow { Layout.fillWidth: true; label: "POWER"; value: "BALANCED"; valueColor: Services.Theme.accent }
            Item { Layout.fillHeight: true }
            Components.FolioLabel { text: "OUTPUT LEVEL" }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 3; color: Services.Theme.surfaceAlt
                Rectangle { width: parent.width * 0.64; height: parent.height; radius: 3; color: Services.Theme.accent; opacity: 0.32 }
                MouseArea {
                    anchors.fill: parent
                    onClicked: event => Services.ShellState.showOsd("VOLUME", event.x / width)
                }
            }
            Components.FolioLabel { Layout.alignment: Qt.AlignRight; text: "64 / 100" }
        }
    }
}
