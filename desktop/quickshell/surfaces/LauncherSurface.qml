pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root

    required property var anchorWindow
    property int currentIndex: 0
    property bool panelVisible: false
    readonly property real availableScreenHeight: anchorWindow && anchorWindow.screen ? anchorWindow.screen.height : 720
    readonly property real availableScreenWidth: anchorWindow && anchorWindow.screen ? anchorWindow.screen.width : 1280
    readonly property bool compact: implicitWidth < 620 || implicitHeight < 500
    readonly property real contentInset: compact ? 20 : 26
    readonly property bool hasMatches: matchingCount > 0
    readonly property bool idle: normalizedQuery.length === 0
    readonly property real microFontSize: compact ? 9 : 10
    readonly property real microLetterSpacing: compact ? 1.3 : 1.6
    readonly property int matchingCount: {
        let count = 0;
        for (let index = 0; index < results.count; index++) {
            if (matches(index))
                count++;
        }
        return count;
    }
    readonly property string normalizedQuery: query.text.trim().toLowerCase()
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "launcher"
    readonly property real resultContentInset: compact ? 8 : 12
    readonly property real resultRowHeight: Math.max(0, Math.min(compact ? 58 : 66, (archiveBody.height - resultContentInset * 2) / Math.max(1, matchingCount)))

    signal appearanceRequested
    signal dismissRequested

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
        if (normalizedQuery.length === 0)
            return true;
        const entry = results.get(index);
        return entry.title.toLowerCase().includes(normalizedQuery) || entry.detail.toLowerCase().includes(normalizedQuery);
    }
    function moveSelection(direction) {
        if (!hasMatches)
            return;
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

    anchor.rect.x: 0
    anchor.rect.y: Services.RailGeometry.surfaceHeight + Services.RailGeometry.outerGap
    anchor.window: anchorWindow
    color: "transparent"
    grabFocus: !qaVisible
    implicitHeight: Math.max(0, Math.min(540, availableScreenHeight - Services.RailGeometry.surfaceHeight - Services.RailGeometry.topGap - Services.RailGeometry.outerGap * 2))
    implicitWidth: Math.max(0, Math.min(720, availableScreenWidth - Services.RailGeometry.outerGap * 2))
    visible: qaVisible || panelVisible

    onVisibleChanged: {
        if (!visible && panelVisible && !qaVisible)
            dismissRequested();
    }

    ListModel {
        id: results

        ListElement {
            action: "launch"
            command: "/usr/bin/ghostty"
            detail: "Start a focused command session"
            title: "Terminal"
        }
        ListElement {
            action: "launch"
            command: "/usr/bin/nautilus"
            detail: "Browse the local archive"
            title: "Files"
        }
        ListElement {
            action: "launch"
            command: "/usr/bin/firefox"
            detail: "Open the web workspace"
            title: "Browser"
        }
        ListElement {
            action: "appearance"
            command: ""
            detail: "Preview the desktop collection"
            title: "Appearance"
        }
    }

    Process {
        id: launchProcess
    }

    Rectangle {
        id: archiveSheet

        anchors.fill: parent
        border.color: Services.Theme.border
        border.width: 1
        clip: true
        color: Services.Theme.surface
        opacity: root.visible ? 1 : 0
        radius: Services.Theme.radius
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

        Item {
            id: archiveHeader

            anchors.left: parent.left
            anchors.leftMargin: root.contentInset
            anchors.right: parent.right
            anchors.rightMargin: root.contentInset
            anchors.top: parent.top
            anchors.topMargin: root.contentInset
            height: root.compact ? 28 : 34

            Components.FolioLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.accent
                font.letterSpacing: root.microLetterSpacing
                font.pixelSize: root.microFontSize
                text: "01 / COMMAND ARCHIVE"
            }
            Components.FolioLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.letterSpacing: root.microLetterSpacing
                font.pixelSize: root.microFontSize
                text: root.idle ? "LOCAL / 04 RECORDS" : root.matchingCount.toString().padStart(2, "0") + " / 04 MATCHED"
                textFormat: Text.PlainText
                visible: archiveHeader.width >= 360
            }
        }

        Rectangle {
            id: searchBackplate

            anchors.left: parent.left
            anchors.leftMargin: root.contentInset
            anchors.right: parent.right
            anchors.rightMargin: root.contentInset
            anchors.top: archiveHeader.bottom
            border.color: query.activeFocus ? Services.Theme.accent : Services.Theme.border
            border.width: 1
            color: Services.Theme.background
            height: root.compact ? 54 : 62
            radius: Math.max(4, Services.Theme.radius * 0.45)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.accent
                font.family: Services.Theme.monoFamily
                font.pixelSize: 11
                text: "/"
            }
            TextInput {
                id: query

                anchors.left: parent.left
                anchors.leftMargin: 42
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.text
                focus: root.visible
                font.family: Services.Theme.fontFamily
                font.pixelSize: root.compact ? 18 : 21
                selectionColor: Services.Theme.accent

                Component.onCompleted: {
                    if (root.qaVisible)
                        text = Quickshell.env("INFINITY_QA_LAUNCHER_QUERY");
                }
                onTextChanged: root.selectFirstMatch()

                Keys.onDownPressed: root.moveSelection(1)
                Keys.onEscapePressed: root.dismissRequested()
                Keys.onReturnPressed: root.activate(root.currentIndex)
                Keys.onUpPressed: root.moveSelection(-1)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Services.Theme.muted
                    font.capitalization: Font.AllUppercase
                    font.family: Services.Theme.monoFamily
                    font.letterSpacing: 1.2
                    font.pixelSize: root.compact ? 10 : 11
                    text: "Filter local command records"
                    visible: query.text.length === 0
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: root.contentInset
            anchors.right: parent.right
            anchors.rightMargin: root.contentInset
            anchors.top: searchBackplate.bottom
            anchors.topMargin: root.compact ? 12 : 16
            color: Services.Theme.border
            height: 1
        }

        Item {
            id: archiveBody

            anchors.bottom: archiveFooter.top
            anchors.bottomMargin: root.compact ? 10 : 14
            anchors.left: parent.left
            anchors.leftMargin: root.contentInset
            anchors.right: parent.right
            anchors.rightMargin: root.contentInset
            anchors.top: searchBackplate.bottom
            anchors.topMargin: root.compact ? 13 : 17
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.72)
                radius: Math.max(4, Services.Theme.radius * 0.45)
            }

            Item {
                id: idleArchive

                anchors.fill: parent
                opacity: root.idle ? 1 : 0
                scale: root.idle ? 1 : 0.96
                transformOrigin: Item.Center

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

                Components.ArchiveBlackHole {
                    id: archiveOrbit

                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.top: parent.top
                    inkColor: Services.Theme.muted
                    opacity: 0.76
                    shadowColor: Services.Theme.background
                    width: Math.max(0, parent.width - idleMetadata.width * 0.62)
                }

                Item {
                    id: accessionConnector

                    height: 9
                    width: Math.max(0, archiveOrbit.x + archiveOrbit.width * 0.42 - x)
                    x: idleMetadata.x + idleMetadata.width - 1
                    y: idleMetadata.y + (root.compact ? 24 : 30)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Services.Theme.border
                        height: 1
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        border.color: Services.Theme.muted
                        border.width: 1
                        color: Services.Theme.background
                        height: 5
                        radius: 2.5
                        width: 5
                    }
                }

                Rectangle {
                    id: idleMetadata

                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.compact ? 16 : 22
                    anchors.left: parent.left
                    anchors.leftMargin: root.compact ? 16 : 22
                    border.color: Services.Theme.border
                    border.width: 1
                    color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.96)
                    height: root.compact ? 104 : 118
                    radius: 4
                    width: Math.min(root.compact ? 190 : 220, parent.width * 0.44)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        color: Services.Theme.accent
                        height: 1
                        width: parent.width * 0.42
                    }
                    Column {
                        anchors.fill: parent
                        anchors.margins: root.compact ? 12 : 15
                        spacing: root.compact ? 5 : 7

                        Components.FolioLabel {
                            color: Services.Theme.accent
                            font.letterSpacing: root.microLetterSpacing
                            font.pixelSize: root.microFontSize
                            text: "CATALOGUE / LOCAL"
                        }
                        Text {
                            color: Services.Theme.text
                            font.family: Services.Theme.fontFamily
                            font.pixelSize: root.compact ? 15 : 17
                            font.weight: Font.Medium
                            maximumLineCount: 2
                            text: "Four fixed instruments"
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            color: Services.Theme.muted
                            font.family: Services.Theme.monoFamily
                            font.letterSpacing: root.compact ? 0.8 : 1.1
                            font.pixelSize: root.compact ? 8 : 9
                            text: "CURATED INDEX  /  READY"
                        }
                    }
                }

                Components.FolioLabel {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    font.letterSpacing: root.microLetterSpacing
                    font.pixelSize: root.microFontSize
                    text: "EVENT HORIZON / 01"
                }
            }

            Item {
                id: resultIndex

                anchors.fill: parent
                opacity: root.idle ? 0 : 1
                scale: root.idle ? 1.018 : 1
                transformOrigin: Item.Center

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

                Column {
                    anchors.fill: parent
                    anchors.margins: root.resultContentInset
                    spacing: 0

                    Repeater {
                        model: results

                        Item {
                            id: resultRow

                            required property string detail
                            required property int index
                            required property string title
                            readonly property bool selected: index === root.currentIndex

                            height: visible ? root.resultRowHeight : 0
                            visible: root.matches(index)
                            width: parent.width

                            Rectangle {
                                anchors.fill: parent
                                border.color: resultRow.selected ? Services.Theme.accent : "transparent"
                                border.width: 1
                                color: resultRow.selected ? Services.Theme.surfaceAlt : (resultMouse.containsMouse ? Services.Theme.surface : "transparent")
                                radius: 3
                                scale: resultMouse.pressed ? 0.992 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Services.Theme.duration
                                    }
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                color: Services.Theme.border
                                height: resultRow.selected ? 0 : 1
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.top: parent.top
                                color: resultRow.selected ? Services.Theme.accent : "transparent"
                                width: 4
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 17
                                anchors.verticalCenter: parent.verticalCenter
                                color: resultRow.selected ? Services.Theme.accent : Services.Theme.muted
                                font.family: Services.Theme.monoFamily
                                font.pixelSize: root.compact ? 9 : 10
                                text: (resultRow.index + 1).toString().padStart(2, "0")
                                textFormat: Text.PlainText
                            }
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: root.compact ? 52 : 60
                                anchors.right: selectionMark.left
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    color: resultRow.selected ? Services.Theme.text : Services.Theme.muted
                                    elide: Text.ElideRight
                                    font.family: Services.Theme.fontFamily
                                    font.pixelSize: root.compact ? 13 : 15
                                    font.weight: resultRow.selected ? Font.DemiBold : Font.Normal
                                    text: resultRow.title
                                    textFormat: Text.PlainText
                                    width: parent.width
                                }
                                Text {
                                    color: Services.Theme.muted
                                    elide: Text.ElideRight
                                    font.family: Services.Theme.monoFamily
                                    font.pixelSize: root.compact ? 9 : 10
                                    text: resultRow.detail
                                    textFormat: Text.PlainText
                                    width: parent.width
                                }
                            }
                            Components.FolioLabel {
                                id: selectionMark

                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: resultRow.selected ? Services.Theme.accent : Services.Theme.muted
                                font.letterSpacing: root.microLetterSpacing
                                font.pixelSize: root.microFontSize
                                text: resultRow.width >= 390 ? (resultRow.selected ? "OPEN / ENTER" : "-") : ""
                                visible: text.length > 0
                            }
                            MouseArea {
                                id: resultMouse

                                anchors.fill: parent
                                enabled: !root.idle
                                hoverEnabled: true
                                onClicked: root.activate(resultRow.index)
                                onEntered: root.currentIndex = resultRow.index
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 9
                    visible: !root.hasMatches
                    width: Math.max(0, parent.width - (root.compact ? 24 : 32))

                    Components.FolioLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Services.Theme.accent
                        font.letterSpacing: root.microLetterSpacing
                        font.pixelSize: root.microFontSize
                        horizontalAlignment: Text.AlignHCenter
                        text: "NO MATCHING RECORDS"
                        width: parent.width
                    }
                    Text {
                        color: Services.Theme.muted
                        elide: Text.ElideMiddle
                        font.family: Services.Theme.fontFamily
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        text: "The fixed local index contains no entry for \"" + query.text + "\"."
                        textFormat: Text.PlainText
                        width: parent.width
                    }
                }
            }
        }

        Item {
            id: archiveFooter

            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.compact ? 12 : 18
            anchors.left: parent.left
            anchors.leftMargin: root.contentInset
            anchors.right: parent.right
            anchors.rightMargin: root.contentInset
            height: 18

            Components.FolioLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                font.letterSpacing: root.microLetterSpacing
                font.pixelSize: root.microFontSize
                text: root.idle ? (root.compact ? "TYPE TO FILTER" : "TYPE TO FILTER THE LOCAL INDEX") : (!root.hasMatches ? "TYPE TO REVISE QUERY" : (root.compact ? "UP / DOWN   ENTER" : "UP / DOWN SELECT   ENTER OPEN"))
            }
            Components.FolioLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.letterSpacing: root.microLetterSpacing
                font.pixelSize: root.microFontSize
                text: "ESC / CLOSE"
            }
        }
    }
}
