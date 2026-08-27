import QtQuick
import "../services" as Services

Item {
    id: root
    property string title: "Theme"
    property string mode: "dark"
    property color backgroundColor: "#0b0f14"
    property color surfaceColor: "#141a21"
    property color textColor: "#edf1f5"
    property color accentColor: "#7ea6c9"
    property bool selected: false
    signal chosen
    width: 260
    height: 184

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.backgroundColor
        border.width: root.selected || mouse.containsMouse ? 2 : 1
        border.color: root.selected ? root.accentColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.2)
        scale: mouse.pressed ? 0.985 : (mouse.containsMouse ? 1.015 : 1)
        Behavior on scale { NumberAnimation { duration: Services.Theme.duration; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Services.Theme.duration } }

        Rectangle {
            x: 18; y: 18; width: 26; height: 148
            color: root.surfaceColor
            Rectangle { x: 7; y: 12; width: 12; height: 2; color: root.accentColor }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: 7; y: 40 + index * 23; width: 12; height: 1
                    color: root.textColor; opacity: 0.5
                }
            }
        }
        Rectangle {
            x: 62; y: 32; width: 166; height: 86
            radius: 5; color: root.surfaceColor
            Rectangle { x: 14; y: 14; width: 72; height: 5; color: root.textColor; opacity: 0.8 }
            Rectangle { x: 14; y: 30; width: 116; height: 2; color: root.textColor; opacity: 0.28 }
            Rectangle { x: 14; y: 49; width: 130; height: 20; color: root.accentColor; opacity: 0.22 }
        }
        Text {
            x: 62; y: 139
            text: root.title
            color: root.textColor
            font.family: Services.Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 15
            text: root.mode.toUpperCase()
            color: root.accentColor
            font.family: Services.Theme.monoFamily
            font.pixelSize: 8
            font.letterSpacing: 1.4
        }
    }

    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.chosen() }
}
