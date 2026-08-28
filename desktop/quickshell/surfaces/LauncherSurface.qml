import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root
    required property var anchorWindow
    property int currentIndex: 0
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width + 18
    anchor.rect.y: 92
    implicitWidth: 560
    implicitHeight: 430
    visible: Quickshell.env("INFINITY_QA") === "launcher"
    color: "transparent"
    grabFocus: Quickshell.env("INFINITY_QA") === ""

    ListModel {
        id: results
        ListElement { title: "Terminal"; detail: "Start a focused command session" }
        ListElement { title: "Files"; detail: "Browse the local archive" }
        ListElement { title: "Appearance"; detail: "Preview the desktop collection" }
    }

    Rectangle {
        anchors.fill: parent
        radius: Services.Theme.radius
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.97)
        border.width: 1; border.color: Services.Theme.border
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.975
        transformOrigin: Item.TopLeft
        Behavior on opacity { NumberAnimation { duration: Services.Theme.duration } }
        Behavior on scale { NumberAnimation { duration: Services.Theme.duration; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 26; spacing: 16
            Components.FolioLabel { text: "01 / COMMAND INDEX" }
            TextInput {
                id: query
                Layout.fillWidth: true; Layout.preferredHeight: 52
                color: Services.Theme.text; selectionColor: Services.Theme.accent
                font.family: Services.Theme.fontFamily; font.pixelSize: 24
                focus: root.visible
                Text { anchors.verticalCenter: parent.verticalCenter; visible: query.text.length === 0; text: "Type a command"; color: Services.Theme.muted; font: query.font }
                Keys.onEscapePressed: root.visible = false
                Keys.onDownPressed: root.currentIndex = Math.min(results.count - 1, root.currentIndex + 1)
                Keys.onUpPressed: root.currentIndex = Math.max(0, root.currentIndex - 1)
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Services.Theme.border }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                Repeater {
                    model: query.text.length === 0 ? results : results
                    Rectangle {
                        required property int index
                        required property string title
                        required property string detail
                        Layout.fillWidth: true; Layout.preferredHeight: 70
                        color: index === root.currentIndex ? Services.Theme.surfaceAlt : "transparent"
                        Rectangle { width: 3; height: parent.height - 24; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: index === root.currentIndex ? Services.Theme.accent : "transparent" }
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                            Text { text: title; color: Services.Theme.text; font.family: Services.Theme.fontFamily; font.pixelSize: 14 }
                            Text { text: detail; color: Services.Theme.muted; font.family: Services.Theme.fontFamily; font.pixelSize: 11 }
                        }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.currentIndex = index }
                    }
                }
            }
            Components.FolioLabel { text: query.text.length === 0 ? "LOCAL INDEX / BACKEND WIRING PENDING" : "FILTERING LOCAL INDEX" }
        }
    }
}
