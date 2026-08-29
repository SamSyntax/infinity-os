import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root
    required property var anchorWindow
    property bool panelVisible: false
    property int selectedIndex: 0
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "themes"
    readonly property var selectedTheme: Services.Theme.catalog.length > selectedIndex ? Services.Theme.catalog[selectedIndex] : null
    signal dismissRequested
    anchor.window: anchorWindow
    anchor.rect.x: anchorWindow.width + 18
    anchor.rect.y: 164
    implicitWidth: 918
    implicitHeight: 360
    visible: qaVisible || panelVisible
    color: "transparent"
    grabFocus: !qaVisible
    onVisibleChanged: {
        if (!visible && panelVisible && !qaVisible)
            dismissRequested();
    }
    onPanelVisibleChanged: {
        if (panelVisible) {
            syncSelection();
        } else {
            Services.Theme.clearPreview();
        }
    }

    function syncSelection() {
        for (let index = 0; index < Services.Theme.catalog.length; index++) {
            if (Services.Theme.catalog[index].id === Services.Theme.currentThemeId) {
                selectedIndex = index;
                return;
            }
        }
        selectedIndex = 0;
    }

    function selectTheme(theme, index) {
        selectedIndex = index;
        Services.Theme.preview(theme);
    }

    Connections {
        target: Services.Theme
        function onCatalogChanged() {
            root.syncSelection();
        }
    }

    Rectangle {
        focus: root.visible
        Keys.onLeftPressed: {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1);
            if (root.selectedTheme !== null)
                Services.Theme.preview(root.selectedTheme);
        }
        Keys.onReturnPressed: {
            if (root.selectedTheme !== null)
                Services.Theme.apply(root.selectedTheme.id);
        }
        Keys.onRightPressed: {
            root.selectedIndex = Math.min(Services.Theme.catalog.length - 1, root.selectedIndex + 1);
            if (root.selectedTheme !== null)
                Services.Theme.preview(root.selectedTheme);
        }
        Keys.onEscapePressed: root.dismissRequested()
        anchors.fill: parent
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
                        text: "03 / APPEARANCE EDITIONS"
                    }
                    Text {
                        text: "Living proofs"
                        color: Services.Theme.text
                        font.family: Services.Theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                }
                Components.FolioLabel {
                    text: Services.Theme.applying ? "APPLYING" : "PREVIEW / ENTER TO COMMIT"
                }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                contentWidth: themeRow.width
                contentHeight: themeRow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: themeRow
                    spacing: 16

                    Repeater {
                        model: Services.Theme.catalog

                        Components.ThemeCard {
                            required property int index
                            required property var modelData

                            accentColor: modelData.palette.accent
                            active: modelData.id === Services.Theme.currentThemeId
                            backgroundColor: modelData.palette.background
                            mode: modelData.mode
                            selected: root.selectedIndex === index
                            surfaceColor: modelData.palette.surface
                            textColor: modelData.palette.text
                            title: modelData.name

                            onChosen: root.selectTheme(modelData, index)
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    color: Services.Theme.applyError.length > 0 ? Services.Theme.error : Services.Theme.muted
                    elide: Text.ElideRight
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 10
                    text: Services.Theme.applyError.length > 0 ? Services.Theme.applyError : (root.selectedTheme === null ? "LOADING THEME CATALOG" : "PREVIEWING " + root.selectedTheme.name.toUpperCase())
                }
                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: 150
                    color: applyMouse.pressed ? Services.Theme.surfaceAlt : Services.Theme.accent
                    opacity: Services.Theme.applying || root.selectedTheme === null ? 0.45 : 1
                    radius: Math.max(3, Services.Theme.radius / 2)

                    Text {
                        anchors.centerIn: parent
                        color: Services.Theme.background
                        font.family: Services.Theme.monoFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        text: Services.Theme.applying ? "APPLYING" : "APPLY THEME"
                    }
                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        enabled: !Services.Theme.applying && root.selectedTheme !== null
                        onClicked: Services.Theme.apply(root.selectedTheme.id)
                    }
                }
            }
        }
    }
}
