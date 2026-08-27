import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root
    required property var anchorWindow
    property int selectedIndex: 0
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width + 18
    anchor.rect.y: 164
    implicitWidth: 918
    implicitHeight: 360
    visible: Quickshell.env("INFINITY_QA") === "themes"
    color: "transparent"
    grabFocus: true

    Rectangle {
        focus: root.visible
        Keys.onLeftPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
        Keys.onRightPressed: root.selectedIndex = Math.min(2, root.selectedIndex + 1)
        Keys.onEscapePressed: root.visible = false
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
            anchors.fill: parent; anchors.margins: 24; spacing: 16
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Components.FolioLabel { text: "03 / APPEARANCE EDITIONS" }
                    Text { text: "Living proofs"; color: Services.Theme.text; font.family: Services.Theme.fontFamily; font.pixelSize: 24; font.weight: Font.DemiBold }
                }
                Components.FolioLabel { text: "PREVIEW / COMMIT PENDING" }
            }
            RowLayout {
                spacing: 16
                Components.ThemeCard {
                    title: "Nocturne Index"; mode: "dark"
                    backgroundColor: "#0b0f14"; surfaceColor: "#151c23"; textColor: "#edf1f5"; accentColor: "#7ea6c9"
                    selected: root.selectedIndex === 0
                    onChosen: root.selectedIndex = 0
                }
                Components.ThemeCard {
                    title: "Aurora Margin"; mode: "light"
                    backgroundColor: "#f4f0e7"; surfaceColor: "#fffaf0"; textColor: "#252a30"; accentColor: "#627fa4"
                    selected: root.selectedIndex === 1
                    onChosen: root.selectedIndex = 1
                }
                Components.ThemeCard {
                    title: "Signal Archive"; mode: "dark"
                    backgroundColor: "#090909"; surfaceColor: "#111110"; textColor: "#d8d3c8"; accentColor: "#c8c1b4"
                    selected: root.selectedIndex === 2
                    onChosen: root.selectedIndex = 2
                }
            }
            Components.FolioLabel { text: root.selectedIndex === 0 ? "PREVIEWING NOCTURNE INDEX" : (root.selectedIndex === 1 ? "PREVIEWING AURORA MARGIN" : "PREVIEWING SIGNAL ARCHIVE") }
        }
    }
}
