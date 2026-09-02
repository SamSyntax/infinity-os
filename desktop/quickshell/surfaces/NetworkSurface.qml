import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root

    required property var anchorWindow
    property bool panelVisible: false
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "network"

    signal dismissRequested

    function connectionValue(value) {
        if (!Services.Network.available)
            return "UNAVAILABLE";
        if (!Services.Network.connected)
            return "DISCONNECTED";
        return value.length > 0 ? value : "UNAVAILABLE";
    }

    function stateValue(state, value, suffix) {
        if (state === "measuring")
            return "MEASURING";
        if (state !== "available")
            return "UNAVAILABLE";
        return value + suffix;
    }

    function formatRate(state, bytesPerSecond) {
        if (state === "measuring")
            return "MEASURING";
        if (state !== "available")
            return "UNAVAILABLE";
        if (bytesPerSecond >= 1048576)
            return (bytesPerSecond / 1048576).toFixed(1) + " MiB/s";
        if (bytesPerSecond >= 1024)
            return (bytesPerSecond / 1024).toFixed(1) + " KiB/s";
        return Math.round(bytesPerSecond) + " B/s";
    }

    anchor.window: anchorWindow
    anchor.rect.x: Math.max(Services.RailGeometry.outerGap, anchorWindow.width - implicitWidth)
    anchor.rect.y: anchorWindow.height + Services.RailGeometry.outerGap
    color: "transparent"
    grabFocus: !qaVisible
    implicitHeight: 486
    implicitWidth: 354
    visible: qaVisible || panelVisible

    onVisibleChanged: {
        if (!visible && panelVisible && !qaVisible)
            dismissRequested();
    }

    Rectangle {
        anchors.fill: parent
        border.color: Services.Theme.border
        border.width: 1
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.96)
        focus: root.visible
        opacity: root.visible ? 1 : 0
        radius: Services.Theme.radius
        scale: root.visible ? 1 : 0.97
        transformOrigin: Item.TopRight

        Keys.onEscapePressed: root.dismissRequested()

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
            anchors.margins: 22
            spacing: 12

            Components.FolioLabel {
                text: "03 / NETWORK FIELD"
            }
            Text {
                color: Services.Theme.text
                font.family: Services.Theme.fontFamily
                font.pixelSize: 24
                font.weight: Font.DemiBold
                text: "Signal record"
            }
            Text {
                Layout.fillWidth: true
                color: Services.Theme.muted
                font.family: Services.Theme.fontFamily
                font.pixelSize: 12
                text: "Live interface counters and a restrained probe of the local gateway."
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Services.Theme.border
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "CONNECTION"
                value: root.connectionValue(Services.Network.primaryName)
                valueColor: Services.Network.connected ? Services.Theme.text : Services.Theme.muted
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "TYPE"
                value: root.connectionValue(Services.Network.primaryType).toUpperCase()
                valueColor: Services.Network.connected ? Services.Theme.text : Services.Theme.muted
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "INTERFACE"
                value: root.connectionValue(Services.Network.device)
                valueColor: Services.Network.connected ? Services.Theme.accent : Services.Theme.muted
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "CONNECTIVITY"
                value: Services.Network.available ? Services.Network.connectivity.toUpperCase() : "UNAVAILABLE"
                valueColor: Services.Network.connected ? Services.Theme.success : Services.Theme.muted
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Services.Theme.border
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "DOWN"
                value: root.formatRate(Services.Network.transferState, Services.Network.downBytesPerSecond)
                valueColor: Services.Network.transferState === "available" ? Services.Theme.text : Services.Theme.muted
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "UP"
                value: root.formatRate(Services.Network.transferState, Services.Network.upBytesPerSecond)
                valueColor: Services.Network.transferState === "available" ? Services.Theme.text : Services.Theme.muted
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Services.Theme.border
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "GATEWAY"
                value: Services.Network.gatewayState === "available" ? Services.Network.gateway : (Services.Network.gatewayState === "measuring" ? "MEASURING" : "UNAVAILABLE")
                valueColor: Services.Network.gatewayState === "available" ? Services.Theme.accent : Services.Theme.muted
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "PACKET LOSS"
                value: root.stateValue(Services.Network.packetLossState, Services.Network.packetLossPercent.toFixed(1), "%")
                valueColor: Services.Network.packetLossState === "available" ? Services.Theme.text : Services.Theme.muted
            }
            Components.StatusRow {
                Layout.fillWidth: true
                label: "AVG LATENCY"
                value: root.stateValue(Services.Network.latencyState, Services.Network.averageLatencyMs.toFixed(1), " ms")
                valueColor: Services.Network.latencyState === "available" ? Services.Theme.text : Services.Theme.muted
            }
            Item {
                Layout.fillHeight: true
            }
            Components.FolioLabel {
                Layout.alignment: Qt.AlignRight
                text: Services.Network.connected ? "LOCAL GATEWAY ONLY" : "NO ACTIVE LINK"
            }
        }
    }
}
