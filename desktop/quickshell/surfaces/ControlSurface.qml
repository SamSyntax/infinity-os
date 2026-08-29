import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root
    required property var anchorWindow
    property bool panelVisible: false
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "control"
    readonly property real outputLevel: Services.Audio.outputLevel
    signal dismissRequested

    function setOutputLevel(value) {
        const level = Math.max(0, Math.min(1, value));
        Services.Audio.setOutputLevel(level);
        Services.ShellState.showOsd("VOLUME", level);
    }

    anchor.window: anchorWindow
    anchor.rect.x: Math.max(12, anchorWindow.width - implicitWidth - 12)
    anchor.rect.y: anchorWindow.height + 12
    implicitWidth: 340
    implicitHeight: 410
    visible: qaVisible || panelVisible
    color: "transparent"
    grabFocus: !qaVisible
    onVisibleChanged: {
        if (!visible && panelVisible && !qaVisible)
            dismissRequested();
    }

    Rectangle {
        focus: root.visible
        Keys.onEscapePressed: root.dismissRequested()
        anchors.fill: parent
        radius: Services.Theme.radius
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.96)
        border.width: 1
        border.color: Services.Theme.border
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.97
        transformOrigin: Item.TopLeft
        Behavior on opacity {
            NumberAnimation {
                duration: Services.Theme.duration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Services.Theme.duration
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            Components.FolioLabel {
                text: "02 / SYSTEM STATE"
            }
            Text {
                text: "Quiet machinery"
                color: Services.Theme.text
                font.family: Services.Theme.fontFamily
                font.pixelSize: 25
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: "The essential controls stay close. Detail appears only when requested."
                color: Services.Theme.muted
                font.family: Services.Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Services.Theme.border
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "NETWORK"
                value: Services.Network.label
                valueColor: Services.Network.connected ? Services.Theme.success : Services.Theme.muted
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "PROCESSOR"
                value: Services.SystemResources.cpuLabel
                valueColor: Services.Theme.text
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "MEMORY"
                value: Services.SystemResources.memoryLabel
                valueColor: Services.Theme.text
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "POWER"
                value: Services.Power.profile === "unknown" ? Services.Power.label : Services.Power.profile.toUpperCase()
                valueColor: Services.Theme.accent
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "MOTION"
                value: Services.ShellState.reducedMotion ? "REDUCED" : "FULL"
                valueColor: Services.Theme.accent
                interactive: true
                onClicked: Services.ShellState.toggleReducedMotion()
            }
            Item {
                Layout.fillHeight: true
            }
            Components.FolioLabel {
                text: "OUTPUT LEVEL"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 3
                color: Services.Theme.surfaceAlt
                opacity: Services.Audio.available ? 1 : 0.55
                Rectangle {
                    width: parent.width * root.outputLevel
                    height: parent.height
                    radius: 3
                    color: Services.Theme.accent
                    opacity: 0.32
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: Services.Audio.available && !Services.Audio.setting
                    onClicked: event => root.setOutputLevel(event.x / width)
                }
            }
            Components.FolioLabel {
                Layout.alignment: Qt.AlignRight
                text: Services.Audio.available ? Math.round(root.outputLevel * 100) + " / 100" : "OUTPUT UNAVAILABLE"
            }
        }
    }
}
