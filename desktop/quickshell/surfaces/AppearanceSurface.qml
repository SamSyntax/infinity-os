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
    readonly property bool applyInFlight: Services.Theme.applying || Services.Wallpaper.applying
    readonly property string applyError: Services.Theme.applyError.length > 0 ? Services.Theme.applyError : Services.Wallpaper.applyError
    readonly property bool compact: width < 1500 || height < 900
    readonly property bool narrow: width < 960
    readonly property bool short: height < 800
    readonly property real outerGutter: narrow ? 16 : (compact ? 32 : 52)
    readonly property real navigationGutter: narrow ? 16 : (compact ? 28 : 38)
    readonly property real navigationWidth: narrow ? Math.max(76, Math.min(104, width * 0.22)) : (compact ? 132 : 150)
    readonly property real navigationItemWidth: narrow ? navigationWidth : navigationWidth - 18
    readonly property real contentGap: narrow ? 14 : (compact ? 24 : 32)
    readonly property real contentLeft: navigationGutter + navigationWidth + contentGap
    readonly property real previewTopGutter: short ? 20 : (compact ? 30 : 42)
    readonly property real previewFooterGap: short ? 14 : (compact ? 18 : 24)
    readonly property real metadataInset: short ? 14 : (compact ? 18 : 24)
    readonly property real metadataHeight: short ? 70 : (compact ? 80 : 86)
    readonly property real filmstripHeight: short ? 84 : (compact ? 100 : 116)
    readonly property real filmstripBottomGutter: short ? 18 : (compact ? 26 : 36)
    readonly property real filmstripLeft: narrow ? outerGutter : contentLeft
    readonly property real actionContentWidth: narrow ? Math.max(104, Math.min(124, width * 0.2)) : (compact ? 132 : 150)
    readonly property real actionPadding: narrow || short ? 8 : 10
    readonly property real actionWidth: actionContentWidth + actionPadding * 2
    readonly property real actionContentBottomGutter: short ? 18 : (compact ? 28 : 38)
    readonly property real actionPanelBottomMargin: Math.max(10, actionContentBottomGutter - actionPadding)
    readonly property real actionPanelRightMargin: Math.max(8, outerGutter - actionPadding)
    readonly property real filmActionGap: narrow ? 12 : (compact ? 16 : 18)
    readonly property real footerHeight: Math.max(filmstripBottomGutter + filmstripHeight, actionPanelBottomMargin + actionBackplate.height)

    signal dismissRequested

    function select(index) {
        if (applyInFlight || entries.length === 0)
            return;
        selectedIndex = (index + entries.length) % entries.length;
        previewSelection();
    }

    function selectMode(nextMode) {
        if (applyInFlight)
            return;
        if (mode === nextMode)
            return;
        Services.Theme.clearPreview();
        Services.Wallpaper.clearPreview();
        mode = nextMode;
        syncSelection();
    }

    function syncSelection() {
        if (entries.length === 0)
            return;
        const currentId = mode === "themes" ? Services.Theme.currentThemeId : Services.Wallpaper.currentWallpaperId;
        for (let index = 0; index < entries.length; index++) {
            if (entries[index].id === currentId) {
                selectedIndex = index;
                return;
            }
        }
        if (selectedIndex < 0 || selectedIndex >= entries.length)
            selectedIndex = 0;
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
        if (applyInFlight)
            return;
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
            Services.Theme.clearPreview();
            Services.Wallpaper.clearPreview();
            syncSelection();
        } else if (!Services.Theme.applying && !Services.Wallpaper.applying) {
            Services.Theme.clearPreview();
            Services.Wallpaper.clearPreview();
        }
    }

    Connections {
        target: Services.Theme
        function onApplySucceeded(themeId) {
            Services.Theme.clearPreview();
            root.dismissRequested();
        }
        function onApplyErrorChanged() {
            if (!Services.Theme.applying && Services.Theme.applyError.length > 0)
                Services.Theme.clearPreview();
        }
        function onCatalogChanged() {
            if (root.visible && root.mode === "themes")
                root.syncSelection();
        }
    }
    Connections {
        target: Services.Wallpaper
        function onApplySucceeded(wallpaperId) {
            Services.Wallpaper.clearPreview();
            root.dismissRequested();
        }
        function onApplyErrorChanged() {
            if (!Services.Wallpaper.applying && Services.Wallpaper.applyError.length > 0)
                Services.Wallpaper.clearPreview();
        }
        function onCatalogChanged() {
            if (root.visible && root.mode === "wallpapers")
                root.syncSelection();
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
            anchors.leftMargin: root.navigationGutter
            anchors.top: parent.top
            anchors.topMargin: root.short ? 20 : 40
            spacing: root.short ? 10 : 16
            width: root.navigationWidth

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
                width: root.navigationItemWidth
            }

            Item {
                height: root.short ? 40 : 48
                width: root.navigationItemWidth
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
                height: root.short ? 40 : 48
                width: root.navigationItemWidth
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
            id: preview
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.footerHeight + root.previewFooterGap
            anchors.left: parent.left
            anchors.leftMargin: root.contentLeft
            anchors.right: parent.right
            anchors.rightMargin: root.outerGutter
            anchors.top: parent.top
            anchors.topMargin: root.previewTopGutter

            Rectangle {
                anchors.fill: parent
                border.color: Services.Theme.border
                border.width: 1
                color: Services.Theme.surface
                clip: true
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
                    color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.18)
                }
                Rectangle {
                    id: metadataBackplate
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: root.metadataInset
                    border.color: Services.Theme.border
                    border.width: 1
                    color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.94)
                    height: root.metadataHeight
                    radius: 4
                    width: Math.max(0, Math.min(330, parent.width - root.metadataInset * 2))

                    Column {
                        anchors.fill: parent
                        anchors.margins: root.short ? 10 : 14
                        spacing: root.short ? 3 : 5
                        Text {
                            color: Services.Theme.muted
                            font.family: Services.Theme.monoFamily
                            font.letterSpacing: 1.5
                            font.pixelSize: 8
                            text: (root.selectedIndex + 1).toString().padStart(2, "0") + " / " + root.entries.length.toString().padStart(2, "0") + "  " + root.mode.toUpperCase()
                        }
                        Text {
                            color: Services.Theme.text
                            elide: Text.ElideRight
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: root.short ? 18 : (root.compact ? 20 : 22)
                            font.weight: Font.DemiBold
                            maximumLineCount: 1
                            text: root.selectedTitle
                            textFormat: Text.PlainText
                            width: parent.width
                        }
                        Text {
                            color: Services.Theme.accent
                            font.family: Services.Theme.monoFamily
                            font.pixelSize: 8
                            text: root.selectedId.toUpperCase()
                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }

        Flickable {
            id: filmstrip
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.filmstripBottomGutter
            anchors.left: parent.left
            anchors.leftMargin: root.filmstripLeft
            anchors.right: actionBackplate.left
            anchors.rightMargin: root.filmActionGap
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: stripRow.height
            contentWidth: stripRow.width
            height: root.filmstripHeight

            Row {
                id: stripRow
                spacing: 10

                Repeater {
                    model: root.entries

                    Item {
                        required property int index
                        required property var modelData
                        readonly property var wallpaper: root.mode === "themes" ? modelData.wallpaper : modelData
                        height: root.short ? 76 : (root.compact ? 92 : 108)
                        width: root.selectedIndex === index ? (root.short ? 128 : (root.compact ? 152 : 176)) : (root.short ? 100 : (root.compact ? 118 : 136))

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
                                color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.3)
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.88)
                                height: root.short ? 26 : 30
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
                                textFormat: Text.PlainText
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

        Text {
            anchors.bottom: filmstrip.top
            anchors.bottomMargin: 7
            anchors.left: filmstrip.left
            color: Services.Theme.muted
            font.family: Services.Theme.monoFamily
            font.letterSpacing: 1.1
            font.pixelSize: 8
            text: "← / →  BROWSE    DRAG STRIP"
        }

        Rectangle {
            id: actionBackplate
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.actionPanelBottomMargin
            anchors.right: parent.right
            anchors.rightMargin: root.actionPanelRightMargin
            border.color: Services.Theme.border
            border.width: 1
            color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.94)
            height: actionColumn.height + root.actionPadding * 2
            radius: 4
            width: root.actionWidth

            Column {
                id: actionColumn
                anchors.left: parent.left
                anchors.leftMargin: root.actionPadding
                anchors.right: parent.right
                anchors.rightMargin: root.actionPadding
                anchors.top: parent.top
                anchors.topMargin: root.actionPadding
                spacing: root.short ? 6 : 8

                Text {
                    color: Services.Theme.error
                    elide: Text.ElideRight
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 8
                    maximumLineCount: root.short ? 2 : 3
                    text: root.applyError
                    textFormat: Text.PlainText
                    visible: root.applyError.length > 0
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    color: applyMouse.pressed ? Services.Theme.surfaceAlt : Services.Theme.accent
                    height: root.short ? 38 : 46
                    opacity: root.applyInFlight ? 0.5 : 1
                    radius: 4
                    width: parent.width
                    Text {
                        anchors.centerIn: parent
                        color: Services.Theme.background
                        font.family: Services.Theme.monoFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        text: root.applyInFlight ? "APPLYING" : "COMMIT"
                    }
                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        enabled: !root.applyInFlight
                        onClicked: root.commit()
                    }
                }
                Rectangle {
                    border.color: Services.Theme.border
                    border.width: 1
                    color: cancelMouse.containsMouse ? Services.Theme.surfaceAlt : "transparent"
                    height: root.short ? 32 : 38
                    opacity: root.applyInFlight ? 0.45 : 1
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
                        enabled: !root.applyInFlight
                        hoverEnabled: true
                        onClicked: root.cancel()
                    }
                }
            }
        }
    }
}
