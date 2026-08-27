import QtQuick
import "../services" as Services

Item {
    id: root
    property string index: "00"
    property string label: "ACTION"
    signal clicked
    width: 48
    height: 52

    Rectangle {
        anchors.fill: parent
        color: mouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
        border.width: mouse.containsMouse ? 1 : 0
        border.color: Services.Theme.border
        radius: 4
        scale: mouse.pressed ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: Services.Theme.duration } }
        Behavior on scale { NumberAnimation { duration: Services.Theme.duration; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 7
        text: root.index
        color: Services.Theme.accent
        font.family: Services.Theme.monoFamily
        font.pixelSize: 8
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 7
        text: root.label
        color: Services.Theme.text
        font.family: Services.Theme.monoFamily
        font.pixelSize: 8
        font.letterSpacing: 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
