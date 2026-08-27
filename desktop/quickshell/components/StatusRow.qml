import QtQuick
import QtQuick.Layouts
import "../services" as Services

RowLayout {
    id: root
    property string label: "STATUS"
    property string value: "READY"
    property color valueColor: Services.Theme.text
    spacing: 12

    Rectangle {
        Layout.preferredWidth: 4
        Layout.preferredHeight: 4
        radius: 2
        color: root.valueColor
    }
    Text {
        Layout.fillWidth: true
        text: root.label
        color: Services.Theme.muted
        font.family: Services.Theme.fontFamily
        font.pixelSize: 12
    }
    Text {
        text: root.value
        color: root.valueColor
        font.family: Services.Theme.monoFamily
        font.pixelSize: 10
    }
}
