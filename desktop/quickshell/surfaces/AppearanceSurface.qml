import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../services" as Services

PanelWindow {
    id: root

    property bool panelVisible: false
    property string mode: "themes"
    property int selectedIndex: 0
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "appearance"
    readonly property var entries: mode === "themes" ? Services.Theme.catalog : Services.Wallpaper.catalog
    readonly property var selectedItem: entries.length > selectedIndex ? entries[selectedIndex] : null
    readonly property var selectedWallpaper: selectedItem === null ? null : (mode === "themes" ? selectedItem.wallpaper : selectedItem)
    readonly property string selectedTitle: selectedItem === null ? "Loading archive" : (mode === "themes" ? selectedItem.name : selectedItem.title)
    readonly property string selectedId: selectedItem === null ? "--" : selectedItem.id

    signal dismissRequested

    function select(index) {
        if (entries.length === 0)
            return;
        selectedIndex = (index + entries.length) % entries.length;
        previewSelection();
    }

    function selectMode(nextMode) {
        mode = nextMode;
        selectedIndex = 0;
        previewSelection();
    }

    function previewSelection() {
        if (selectedItem === null)
            return;
        if (mode === "themes") {
            Services.Theme.preview(selectedItem);
            Services.Wallpaper.preview(selectedItem.wallpaper);
        } else {
            Services.Theme.clearPreview();
            Services.Wallpaper.preview(selectedItem);
        }
    }

    function cancel() {
        Services.Theme.clearPreview();
        Services.Wallpaper.clearPreview();
        dismissRequested();
    }

    function commit() {
        if (selectedItem === null)
            return;
        if (mode === "themes") {
            Services.Wallpaper.clearPreview();
            Services.Theme.apply(selectedItem.id);
        } else {
            Services.Theme.clearPreview();
            Services.Wallpaper.apply(selectedItem.id);
        }
        dismissRequested();
    }

    anchors {
        bottom: true
        left: true
        right: true
        top: true
    }
    color: "transparent"
    exclusiveZone: 0
    visible: qaVisible || panelVisible
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "infinity-appearance"

    onPanelVisibleChanged: {
        if (panelVisible) {
            selectedIndex = 0;
            previewSelection();
        } else if (!Services.Theme.applying && !Services.Wallpaper.applying) {
            Services.Theme.clearPreview();
            Services.Wallpaper.clearPreview();
        }
    }

    Connections {
        target: Services.Theme
        function onApplySucceeded(themeId) {
            Services.Theme.clearPreview();
        }
    }
    Connections {
        target: Services.Wallpaper
        function onApplySucceeded(wallpaperId) {
            Services.Wallpaper.clearPreview();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.96)
        focus: root.visible

        Keys.onDownPressed: root.selectMode("wallpapers")
        Keys.onEscapePressed: root.cancel()
        Keys.onLeftPressed: root.select(root.selectedIndex - 1)
        Keys.onReturnPressed: root.commit()
        Keys.onRightPressed: root.select(root.selectedIndex + 1)
        Keys.onUpPressed: root.selectMode("themes")

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            opacity: 0.24
            source: root.selectedWallpaper === null ? "" : "file://" + Services.Wallpaper.assetRoot + "/" + root.selectedWallpaper.path
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.56)
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 38
            anchors.top: parent.top
            anchors.topMargin: 40
            spacing: 16
            width: 150

            Text {
                color: Services.Theme.accent
                font.family: Services.Theme.fontFamily
                font.pixelSize: 25
                text: "∞"
            }
            Text {
                color: Services.Theme.muted
                font.family: Services.Theme.monoFamily
                font.letterSpacing: 2
                font.pixelSize: 8
                text: "FIELD ARCHIVE"
            }
            Rectangle {
                color: Services.Theme.border
                height: 1
                width: 132
            }

            Item {
                height: 48
                width: 132
                Rectangle {
                    anchors.fill: parent
                    border.color: root.mode === "themes" ? Services.Theme.accent : "transparent"
                    border.width: 1
                    color: themeModeMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                    radius: 4
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.mode === "themes" ? Services.Theme.text : Services.Theme.muted
                    font.family: Services.Theme.monoFamily
                    font.letterSpacing: 1.2
                    font.pixelSize: 9
                    text: "01  THEMES"
                }
                MouseArea {
                    id: themeModeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.selectMode("themes")
                }
            }
            Item {
                height: 48
                width: 132
                Rectangle {
                    anchors.fill: parent
                    border.color: root.mode === "wallpapers" ? Services.Theme.accent : "transparent"
                    border.width: 1
                    color: wallpaperModeMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                    radius: 4
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.mode === "wallpapers" ? Services.Theme.text : Services.Theme.muted
                    font.family: Services.Theme.monoFamily
                    font.letterSpacing: 1.2
                    font.pixelSize: 9
                    text: "02  WALLS"
                }
                MouseArea {
                    id: wallpaperModeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.selectMode("wallpapers")
                }
            }
        }

        Item {
            anchors.bottom: filmstrip.top
            anchors.bottomMargin: 24
            anchors.left: parent.left
            anchors.leftMargin: 220
            anchors.right: parent.right
            anchors.rightMargin: 52
            anchors.top: parent.top
            anchors.topMargin: 42

            Rectangle {
                anchors.fill: parent
                border.color: Services.Theme.border
                border.width: 1
                color: Services.Theme.surface
                radius: Math.max(5, Services.Theme.radius * 0.7)

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: root.selectedWallpaper === null ? "" : "file://" + Services.Wallpaper.assetRoot + "/" + root.selectedWallpaper.path
                }
                Rectangle {
                    anchors.fill: parent
                    color: "#26000000"
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 24
                    color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.82)
                    height: 86
                    radius: 4
                    width: 330

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 5
                        Text {
                            color: Services.Theme.muted
                            font.family: Services.Theme.monoFamily
                            font.letterSpacing: 1.5
                            font.pixelSize: 8
                            text: (root.selectedIndex + 1).toString().padStart(2, "0") + " / " + root.entries.length.toString().padStart(2, "0") + "  " + root.mode.toUpperCase()
                        }
                        Text {
                            color: Services.Theme.text
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            text: root.selectedTitle
                        }
                        Text {
                            color: Services.Theme.accent
                            font.family: Services.Theme.monoFamily
                            font.pixelSize: 8
                            text: root.selectedId.toUpperCase()
                        }
                    }
                }
            }
        }

        Flickable {
            id: filmstrip
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            anchors.left: parent.left
            anchors.leftMargin: 220
            anchors.right: actionColumn.left
            anchors.rightMargin: 28
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: stripRow.height
            contentWidth: stripRow.width
            height: 116

            Row {
                id: stripRow
                spacing: 10

                Repeater {
                    model: root.entries

                    Item {
                        required property int index
                        required property var modelData
                        readonly property var wallpaper: root.mode === "themes" ? modelData.wallpaper : modelData
                        height: 108
                        width: root.selectedIndex === index ? 176 : 136

                        Behavior on width {
                            NumberAnimation {
                                duration: Services.Theme.duration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            border.color: root.selectedIndex === index ? Services.Theme.accent : Services.Theme.border
                            border.width: root.selectedIndex === index ? 2 : 1
                            color: Services.Theme.surface
                            opacity: stripMouse.containsMouse || root.selectedIndex === index ? 1 : 0.72
                            radius: 4
                            scale: stripMouse.pressed ? 0.985 : 1
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Services.Theme.duration
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Services.Theme.duration
                                }
                            }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                source: "file://" + Services.Wallpaper.assetRoot + "/" + wallpaper.path
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "#59000000"
                            }
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: 9
                                color: "#f1ede4"
                                elide: Text.ElideRight
                                font.family: Services.Theme.monoFamily
                                font.pixelSize: 8
                                text: root.mode === "themes" ? modelData.name.toUpperCase() : modelData.title.toUpperCase()
                                width: parent.width - 18
                            }
                            MouseArea {
                                id: stripMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.select(index)
                            }
                        }
                    }
                }
            }
        }

        Column {
            id: actionColumn
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 38
            anchors.right: parent.right
            anchors.rightMargin: 52
            spacing: 8
            width: 150

            Rectangle {
                color: applyMouse.pressed ? Services.Theme.surfaceAlt : Services.Theme.accent
                height: 46
                opacity: Services.Theme.applying || Services.Wallpaper.applying ? 0.5 : 1
                radius: 4
                width: parent.width
                Text {
                    anchors.centerIn: parent
                    color: Services.Theme.background
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    text: "COMMIT"
                }
                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    enabled: !Services.Theme.applying && !Services.Wallpaper.applying
                    onClicked: root.commit()
                }
            }
            Rectangle {
                border.color: Services.Theme.border
                border.width: 1
                color: cancelMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                height: 38
                radius: 4
                width: parent.width
                Text {
                    anchors.centerIn: parent
                    color: Services.Theme.muted
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 8
                    text: "ESC / CANCEL"
                }
                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.cancel()
                }
            }
        }
    }
}
