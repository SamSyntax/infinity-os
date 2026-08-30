import QtQuick
import "../services" as Services

Item {
    id: root

    property string index: "00"
    property string label: "ACTION"

    signal clicked

    implicitWidth: Math.max(Services.RailGeometry.minimumControlWidth, Math.ceil(Math.max(indexText.implicitWidth, labelText.implicitWidth)) + Services.RailGeometry.controlHorizontalPadding * 2)
    implicitHeight: Services.RailGeometry.controlHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: mouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
        border.width: mouse.containsMouse ? 1 : 0
        border.color: Services.Theme.border
        radius: Services.RailGeometry.controlRadius
        scale: mouse.pressed ? 0.97 : 1
        Behavior on color {
            ColorAnimation {
                duration: Services.Theme.duration
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Services.Theme.duration
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        id: indexText
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Services.RailGeometry.controlHorizontalPadding
        anchors.topMargin: Services.RailGeometry.controlVerticalPadding
        text: root.index
        color: Services.Theme.accent
        font.family: Services.Theme.monoFamily
        font.pixelSize: Services.RailGeometry.controlIndexFontSize
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Services.RailGeometry.controlHorizontalPadding
        anchors.bottomMargin: Services.RailGeometry.controlVerticalPadding
        text: root.label
        color: Services.Theme.text
        font.family: Services.Theme.monoFamily
        font.pixelSize: Services.RailGeometry.controlLabelFontSize
        font.letterSpacing: 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
