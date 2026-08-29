import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../services" as Services

PanelWindow {
    id: root

    signal appearanceRequested
    signal controlRequested
    signal launcherRequested

    readonly property bool compact: width < 1500

    anchors {
        left: true
        right: true
        top: true
    }
    color: "transparent"
    exclusiveZone: visible ? 62 : 0
    implicitHeight: 52
    margins {
        left: 10
        right: 10
        top: 8
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "infinity-navbar"

    Process {
        id: lockProcess
        command: ["/usr/bin/loginctl", "lock-session"]
    }

    Rectangle {
        anchors.fill: parent
        border.color: Services.Theme.border
        border.width: 1
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, Services.Theme.panelOpacity)
        radius: Math.max(5, Services.Theme.radius * 0.65)

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 20
            color: Services.Theme.accent
            height: 1
            opacity: 0.8
            width: 132
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 6

            Item {
                height: parent.height
                width: 78

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Services.Theme.accent
                    font.family: Services.Theme.fontFamily
                    font.pixelSize: 20
                    text: "∞"
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 25
                    anchors.verticalCenter: parent.verticalCenter
                    color: Services.Theme.text
                    font.family: Services.Theme.monoFamily
                    font.letterSpacing: 1.5
                    font.pixelSize: 8
                    text: "INFINITY"
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: 22
                width: 1
            }

            Item {
                height: parent.height
                width: 58

                Rectangle {
                    anchors.fill: parent
                    color: openMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                    opacity: openMouse.pressed ? 0.65 : 1
                    radius: 4
                    Behavior on color {
                        ColorAnimation {
                            duration: Services.Theme.duration
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Services.Theme.duration
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: Services.Theme.text
                    font.family: Services.Theme.monoFamily
                    font.letterSpacing: 1.2
                    font.pixelSize: 9
                    text: "OPEN"
                }
                MouseArea {
                    id: openMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.launcherRequested()
                }
            }

            Item {
                height: parent.height
                width: 62

                Rectangle {
                    anchors.fill: parent
                    color: fieldMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                    opacity: fieldMouse.pressed ? 0.65 : 1
                    radius: 4
                    Behavior on color {
                        ColorAnimation {
                            duration: Services.Theme.duration
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Services.Theme.duration
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: Services.Theme.text
                    font.family: Services.Theme.monoFamily
                    font.letterSpacing: 1.2
                    font.pixelSize: 9
                    text: "FIELD"
                }
                MouseArea {
                    id: fieldMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.appearanceRequested()
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: 22
                width: 1
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: Services.Workspaces.workspaceIds

                    Item {
                        required property int modelData
                        readonly property bool active: Services.Workspaces.activeWorkspaceIdForScreen(root.screen) === modelData
                        readonly property bool occupied: Services.Workspaces.occupied(modelData)
                        height: 30
                        width: active ? 32 : 22

                        Behavior on width {
                            NumberAnimation {
                                duration: Services.Theme.duration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            color: active ? Services.Theme.accent : (occupied ? Services.Theme.text : Services.Theme.muted)
                            height: active ? 4 : 3
                            opacity: active ? 1 : (occupied ? 0.55 : 0.22)
                            radius: 2
                            width: active ? 24 : 4
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
                            color: active ? Services.Theme.accent : Services.Theme.muted
                            font.family: Services.Theme.monoFamily
                            font.pixelSize: 7
                            opacity: workspaceMouse.containsMouse || active ? 0.9 : 0
                            text: modelData
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
                            onClicked: Services.Workspaces.activate(modelData)
                        }
                    }
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.muted
                font.family: Services.Theme.monoFamily
                font.letterSpacing: 1
                font.pixelSize: 8
                text: Services.Time.date.toUpperCase()
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.accent
                height: 18
                width: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.text
                font.family: Services.Theme.monoFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                text: Services.Time.clock
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.muted
                font.family: Services.Theme.monoFamily
                font.pixelSize: 8
                text: Services.SystemResources.cpuLabel
                visible: !root.compact
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.muted
                font.family: Services.Theme.monoFamily
                font.pixelSize: 8
                text: Services.SystemResources.memoryLabel
                visible: !root.compact
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: 22
                visible: !root.compact
                width: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Network.connected ? Services.Theme.text : Services.Theme.muted
                elide: Text.ElideRight
                font.family: Services.Theme.monoFamily
                font.pixelSize: 8
                maximumLineCount: 1
                text: Services.Network.label
                width: root.compact ? 52 : 92
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Power.hasBattery && Services.Power.percentage < 20 ? Services.Theme.warning : Services.Theme.text
                font.family: Services.Theme.monoFamily
                font.pixelSize: 8
                text: Services.Power.label
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.border
                height: 22
                width: 1
            }
            Item {
                height: parent.height
                width: 54

                Rectangle {
                    anchors.fill: parent
                    color: stateMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                    opacity: stateMouse.pressed ? 0.65 : 1
                    radius: 4
                    Behavior on color {
                        ColorAnimation {
                            duration: Services.Theme.duration
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: Services.Theme.text
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 8
                    text: "STATE"
                }
                MouseArea {
                    id: stateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.controlRequested()
                }
            }
            Item {
                height: parent.height
                width: 46

                Rectangle {
                    anchors.fill: parent
                    color: lockMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                    opacity: lockMouse.pressed ? 0.65 : 1
                    radius: 4
                    Behavior on color {
                        ColorAnimation {
                            duration: Services.Theme.duration
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: Services.Theme.text
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 8
                    text: "LOCK"
                }
                MouseArea {
                    id: lockMouse
                    anchors.fill: parent
                    enabled: !lockProcess.running
                    hoverEnabled: true
                    onClicked: lockProcess.running = true
                }
            }
        }
    }
}
