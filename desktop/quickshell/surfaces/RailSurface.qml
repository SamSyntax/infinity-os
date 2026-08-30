pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../components" as Components
import "../services" as Services

PanelWindow {
    id: root

    property string layoutVariant: Quickshell.env("INFINITY_NAVBAR_LAYOUT") === "full" ? "full" : "islands"
    readonly property bool fullWidth: layoutVariant === "full"
    readonly property bool compact: width < Services.RailGeometry.compactBreakpoint
    readonly property bool narrow: width < Services.RailGeometry.narrowBreakpoint

    signal appearanceRequested
    signal controlRequested
    signal launcherRequested

    anchors {
        left: true
        right: true
        top: true
    }
    color: "transparent"
    exclusiveZone: visible ? Services.RailGeometry.exclusiveZone : 0
    implicitHeight: Services.RailGeometry.surfaceHeight
    margins {
        left: Services.RailGeometry.outerGap
        right: Services.RailGeometry.outerGap
        top: Services.RailGeometry.topGap
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "infinity-navbar"

    Process {
        id: lockProcess
        command: ["/usr/bin/loginctl", "lock-session"]
    }

    Components.EnergyConnector {
        id: leftConnector

        height: Services.RailGeometry.dividerHeight
        visible: !root.fullWidth && width > 0
        width: Math.max(0, centerIsland.x - leftIsland.x - leftIsland.width)
        x: leftIsland.x + leftIsland.width
        y: (root.height - height) / 2
    }

    Components.EnergyConnector {
        id: rightConnector

        height: Services.RailGeometry.dividerHeight
        visible: !root.fullWidth && width > 0
        width: Math.max(0, rightIsland.x - centerIsland.x - centerIsland.width)
        x: centerIsland.x + centerIsland.width
        y: (root.height - height) / 2
    }

    Rectangle {
        id: fullSurface

        anchors.fill: parent
        border.color: Services.Theme.border
        border.width: 1
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, Services.Theme.panelOpacity)
        radius: Services.RailGeometry.surfaceRadius
        visible: root.fullWidth
    }

    Rectangle {
        id: leftIsland

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        border.color: Services.Theme.border
        border.width: root.fullWidth ? 0 : 1
        color: root.fullWidth ? "transparent" : Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, Services.Theme.panelOpacity)
        height: Services.RailGeometry.surfaceHeight
        radius: Services.RailGeometry.surfaceRadius
        width: leftContent.childrenRect.width + Services.RailGeometry.horizontalPadding * 2

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: Services.RailGeometry.accentRuleInset
            color: Services.Theme.accent
            height: 1
            opacity: 0.8
            width: Math.min(Services.RailGeometry.accentRuleWidth, parent.width - Services.RailGeometry.accentRuleInset * 2)
        }

        Row {
            id: leftContent

            anchors.left: parent.left
            anchors.leftMargin: Services.RailGeometry.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            height: Services.RailGeometry.controlHeight
            spacing: Services.RailGeometry.sectionSpacing

            Item {
                height: Services.RailGeometry.controlHeight
                width: Services.RailGeometry.brandWidth

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Services.Theme.accent
                    font.family: Services.Theme.fontFamily
                    font.pixelSize: Services.RailGeometry.brandMarkFontSize
                    text: "∞"
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 25
                    anchors.verticalCenter: parent.verticalCenter
                    color: Services.Theme.text
                    font.family: Services.Theme.monoFamily
                    font.letterSpacing: 1.5
                    font.pixelSize: Services.RailGeometry.brandLabelFontSize
                    text: "INFINITY"
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: Services.RailGeometry.dividerHeight
                width: 1
            }

            Components.RailButton {
                index: "01"
                label: "OPEN"
                onClicked: root.launcherRequested()
            }
            Components.RailButton {
                index: "02"
                label: "FIELD"
                onClicked: root.appearanceRequested()
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: Services.RailGeometry.dividerHeight
                width: 1
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                height: Services.RailGeometry.controlHeight
                spacing: Services.RailGeometry.workspaceSpacing

                Repeater {
                    model: Services.Workspaces.workspaceIds

                    Item {
                        id: workspaceItem

                        required property int modelData
                        readonly property bool active: Services.Workspaces.activeWorkspaceIdForScreen(root.screen) === modelData
                        readonly property bool occupied: Services.Workspaces.occupied(modelData)
                        height: Services.RailGeometry.controlHeight
                        width: workspaceItem.active ? (root.narrow ? Services.RailGeometry.workspaceNarrowActiveWidth : Services.RailGeometry.workspaceActiveWidth) : (root.narrow ? Services.RailGeometry.workspaceNarrowWidth : Services.RailGeometry.workspaceWidth)

                        Behavior on width {
                            NumberAnimation {
                                duration: Services.Theme.duration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            color: workspaceItem.active ? Services.Theme.accent : (workspaceItem.occupied ? Services.Theme.text : Services.Theme.muted)
                            height: workspaceItem.active ? 4 : 3
                            opacity: workspaceItem.active ? 1 : (workspaceItem.occupied ? 0.55 : 0.22)
                            radius: 2
                            width: workspaceItem.active ? 22 : 4

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Services.Theme.duration
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: Services.Theme.duration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            color: workspaceItem.active ? Services.Theme.accent : Services.Theme.muted
                            font.family: Services.Theme.monoFamily
                            font.pixelSize: Services.RailGeometry.workspaceFontSize
                            opacity: workspaceMouse.containsMouse || workspaceItem.active ? 0.9 : 0
                            text: workspaceItem.modelData

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Services.Theme.duration
                                }
                            }
                        }
                        MouseArea {
                            id: workspaceMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Services.Workspaces.activate(workspaceItem.modelData)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: centerIsland

        anchors.centerIn: parent
        border.color: Services.Theme.border
        border.width: root.fullWidth ? 0 : 1
        color: root.fullWidth ? "transparent" : Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, Services.Theme.panelOpacity)
        height: Services.RailGeometry.surfaceHeight
        radius: Services.RailGeometry.surfaceRadius
        width: centerContent.childrenRect.width + Services.RailGeometry.horizontalPadding * 2

        Row {
            id: centerContent

            anchors.centerIn: parent
            height: Services.RailGeometry.controlHeight
            spacing: Services.RailGeometry.sectionSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.muted
                font.family: Services.Theme.monoFamily
                font.letterSpacing: 1
                font.pixelSize: Services.RailGeometry.telemetryFontSize
                text: Services.Time.date.toUpperCase()
                visible: !root.narrow
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.accent
                height: Services.RailGeometry.dividerHeight
                visible: !root.narrow
                width: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.text
                font.family: Services.Theme.monoFamily
                font.pixelSize: Services.RailGeometry.clockFontSize
                font.weight: Font.DemiBold
                text: Services.Time.clock
            }
        }
    }

    Rectangle {
        id: rightIsland

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        border.color: Services.Theme.border
        border.width: root.fullWidth ? 0 : 1
        color: root.fullWidth ? "transparent" : Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, Services.Theme.panelOpacity)
        height: Services.RailGeometry.surfaceHeight
        radius: Services.RailGeometry.surfaceRadius
        width: rightContent.childrenRect.width + Services.RailGeometry.horizontalPadding * 2

        Row {
            id: rightContent

            anchors.right: parent.right
            anchors.rightMargin: Services.RailGeometry.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            height: Services.RailGeometry.controlHeight
            spacing: Services.RailGeometry.sectionSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.muted
                font.family: Services.Theme.monoFamily
                font.pixelSize: Services.RailGeometry.telemetryFontSize
                text: Services.SystemResources.cpuLabel
                visible: !root.compact
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.muted
                font.family: Services.Theme.monoFamily
                font.pixelSize: Services.RailGeometry.telemetryFontSize
                text: Services.SystemResources.memoryLabel
                visible: !root.compact
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: Services.RailGeometry.dividerHeight
                visible: !root.compact
                width: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Network.connected ? Services.Theme.text : Services.Theme.muted
                elide: Text.ElideRight
                font.family: Services.Theme.monoFamily
                font.pixelSize: Services.RailGeometry.telemetryFontSize
                maximumLineCount: 1
                text: Services.Network.label
                textFormat: Text.PlainText
                width: Math.min(implicitWidth, root.narrow ? Services.RailGeometry.networkNarrowMaxWidth : Services.RailGeometry.networkMaxWidth)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Power.hasBattery && Services.Power.percentage < 20 ? Services.Theme.warning : Services.Theme.text
                font.family: Services.Theme.monoFamily
                font.pixelSize: Services.RailGeometry.telemetryFontSize
                text: Services.Power.label
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: Services.RailGeometry.dividerHeight
                width: 1
            }
            Components.RailButton {
                index: "03"
                label: "STATE"
                onClicked: root.controlRequested()
            }
            Components.RailButton {
                enabled: !lockProcess.running
                index: "04"
                label: "LOCK"
                onClicked: lockProcess.running = true
            }
        }
    }
}
