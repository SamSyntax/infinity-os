import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root
    required property var anchorWindow
    property bool panelVisible: false
    property int currentIndex: 0
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "launcher"
    signal dismissRequested
    signal appearanceRequested

    function activate(index) {
        if (index < 0 || index >= results.count)
            return;
        const entry = results.get(index);
        if (entry.action === "appearance") {
            dismissRequested();
            appearanceRequested();
            return;
        }
        if (launchProcess.running)
            return;
        launchProcess.command = ["/usr/bin/systemd-run", "--user", "--collect", "--quiet", "--", entry.command];
        launchProcess.running = true;
        dismissRequested();
    }
    function matches(index) {
        const needle = query.text.trim().toLowerCase();
        if (needle.length === 0)
            return true;
        const entry = results.get(index);
        return entry.title.toLowerCase().includes(needle) || entry.detail.toLowerCase().includes(needle);
    }
    function moveSelection(direction) {
        for (let offset = 1; offset <= results.count; offset++) {
            const candidate = (currentIndex + direction * offset + results.count) % results.count;
            if (matches(candidate)) {
                currentIndex = candidate;
                return;
            }
        }
    }
    function selectFirstMatch() {
        for (let index = 0; index < results.count; index++) {
            if (matches(index)) {
                currentIndex = index;
                return;
            }
        }
        currentIndex = -1;
    }
    anchor.window: anchorWindow
    anchor.rect.x: 12
    anchor.rect.y: anchorWindow.height + 12
    implicitWidth: 560
    implicitHeight: 430
    visible: qaVisible || panelVisible
    color: "transparent"
    grabFocus: !qaVisible
    onVisibleChanged: {
        if (!visible && panelVisible && !qaVisible)
            dismissRequested();
    }

    ListModel {
        id: results
        ListElement {
            title: "Terminal"
            detail: "Start a focused command session"
            command: "/usr/bin/ghostty"
            action: "launch"
        }
        ListElement {
            title: "Files"
            detail: "Browse the local archive"
            command: "/usr/bin/nautilus"
            action: "launch"
        }
        ListElement {
            title: "Browser"
            detail: "Open the web workspace"
            command: "/usr/bin/firefox"
            action: "launch"
        }
        ListElement {
            title: "Appearance"
            detail: "Preview the desktop collection"
            command: ""
            action: "appearance"
        }
    }

    Process {
        id: launchProcess
    }

    Rectangle {
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
            anchors.margins: 26
            spacing: 16
            Components.FolioLabel {
                text: "01 / COMMAND INDEX"
            }
            TextInput {
                id: query
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: Services.Theme.text
                selectionColor: Services.Theme.accent
                font.family: Services.Theme.fontFamily
                font.pixelSize: 24
                focus: root.visible
                onTextChanged: root.selectFirstMatch()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: query.text.length === 0
                    text: "Type a command"
                    color: Services.Theme.muted
                    font: query.font
                }
                Keys.onEscapePressed: root.dismissRequested()
                Keys.onReturnPressed: root.activate(root.currentIndex)
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Services.Theme.border
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Repeater {
                    model: results
                    Rectangle {
                        required property int index
                        required property string title
                        required property string detail
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 70 : 0
                        color: index === root.currentIndex ? Services.Theme.surfaceAlt : "transparent"
                        visible: root.matches(index)
                        Rectangle {
                            width: 3
                            height: parent.height - 24
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: index === root.currentIndex ? Services.Theme.accent : "transparent"
                        }
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: title
                                color: Services.Theme.text
                                font.family: Services.Theme.fontFamily
                                font.pixelSize: 14
                            }
                            Text {
                                text: detail
                                color: Services.Theme.muted
                                font.family: Services.Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.currentIndex = index
                            onClicked: root.activate(index)
                        }
                    }
                }
            }
            Components.FolioLabel {
                text: "ENTER TO OPEN / ESC TO CLOSE"
            }
        }
    }
}
