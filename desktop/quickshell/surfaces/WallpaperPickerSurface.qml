import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root

    required property var anchorWindow
    property bool panelVisible: false
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "wallpapers"

    signal dismissRequested

    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width + 18
    anchor.rect.y: 236
    implicitWidth: 816
    implicitHeight: 330
    visible: qaVisible || panelVisible
    color: "transparent"
    grabFocus: !qaVisible

    onVisibleChanged: {
        if (!visible && panelVisible && !qaVisible)
            dismissRequested();
    }

    Rectangle {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.dismissRequested()
        radius: Services.Theme.radius
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.97)
        border.width: 1
        border.color: Services.Theme.border
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.975
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

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Components.FolioLabel {
                        text: "04 / WALLPAPER ARCHIVE"
                    }
                    Text {
                        text: "Change the field"
                        color: Services.Theme.text
                        font.family: Services.Theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                }
                Components.FolioLabel {
                    text: Services.Wallpaper.applying ? "APPLYING" : "SELECT TO APPLY"
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                contentWidth: wallpaperRow.width
                contentHeight: wallpaperRow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: wallpaperRow
                    spacing: 14

                    Repeater {
                        model: Services.Wallpaper.catalog

                        Item {
                            required property var modelData
                            width: 240
                            height: 174

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.max(4, Services.Theme.radius / 2)
                                color: Services.Theme.surfaceAlt
                                border.width: modelData.id === Services.Wallpaper.currentWallpaperId ? 2 : 1
                                border.color: modelData.id === Services.Wallpaper.currentWallpaperId ? Services.Theme.accent : Services.Theme.border
                                scale: wallpaperMouse.pressed ? 0.985 : (wallpaperMouse.containsMouse ? 1.012 : 1)
                                clip: true

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Services.Theme.duration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Services.Theme.duration
                                    }
                                }

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + Services.Wallpaper.assetRoot + "/" + modelData.path
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#66000000"
                                }
                                Text {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 14
                                    text: modelData.title
                                    color: "#f4f1e9"
                                    font.family: Services.Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Components.FolioLabel {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 14
                                    text: modelData.id === Services.Wallpaper.currentWallpaperId ? "ACTIVE" : "APPLY"
                                }
                                MouseArea {
                                    id: wallpaperMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !Services.Wallpaper.applying
                                    onClicked: Services.Wallpaper.apply(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                color: Services.Wallpaper.applyError.length > 0 ? Services.Theme.error : Services.Theme.muted
                elide: Text.ElideRight
                font.family: Services.Theme.monoFamily
                font.pixelSize: 10
                text: Services.Wallpaper.applyError.length > 0 ? Services.Wallpaper.applyError : "ATOMIC APPLY / CURRENT THEME REMAINS INTACT"
            }
        }
    }
}
