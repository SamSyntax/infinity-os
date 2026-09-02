pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../services" as Services

PopupWindow {
    id: root

    required property var anchorWindow
    property bool panelVisible: false
    property int displayedMonth: 0
    property int displayedYear: 1970
    readonly property bool qaVisible: Quickshell.env("INFINITY_QA") === "calendar"
    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    readonly property var weekdayNames: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    readonly property var calendarDays: buildCalendar(displayedYear, displayedMonth)

    signal dismissRequested

    function resetMonth() {
        const today = new Date();
        displayedYear = today.getFullYear();
        displayedMonth = today.getMonth();
    }

    function changeMonth(offset) {
        const next = new Date(displayedYear, displayedMonth + offset, 1);
        displayedYear = next.getFullYear();
        displayedMonth = next.getMonth();
    }

    function buildCalendar(year, month) {
        const firstWeekday = (new Date(year, month, 1).getDay() + 6) % 7;
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const today = new Date();
        const days = [];
        for (let cell = 0; cell < 42; cell++) {
            const day = cell - firstWeekday + 1;
            days.push({
                day: day >= 1 && day <= daysInMonth ? day : 0,
                today: day === today.getDate() && month === today.getMonth() && year === today.getFullYear()
            });
        }
        return days;
    }

    anchor.window: anchorWindow
    anchor.rect.x: Math.max(Services.RailGeometry.outerGap, Math.round((anchorWindow.width - implicitWidth) / 2))
    anchor.rect.y: anchorWindow.height + Services.RailGeometry.outerGap
    color: "transparent"
    grabFocus: !qaVisible
    implicitHeight: 440
    implicitWidth: 338
    visible: qaVisible || panelVisible

    Component.onCompleted: resetMonth()
    onPanelVisibleChanged: {
        if (panelVisible)
            resetMonth();
    }
    onVisibleChanged: {
        if (!visible && panelVisible && !qaVisible)
            dismissRequested();
    }

    Rectangle {
        anchors.fill: parent
        border.color: Services.Theme.border
        border.width: 1
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.96)
        focus: root.visible
        opacity: root.visible ? 1 : 0
        radius: Services.Theme.radius
        scale: root.visible ? 1 : 0.97
        transformOrigin: Item.Top

        Keys.onEscapePressed: root.dismissRequested()

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
            anchors.margins: 22
            spacing: 12

            Components.FolioLabel {
                text: "TIME / MONTH INDEX"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    color: Services.Theme.text
                    font.family: Services.Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    text: root.monthNames[root.displayedMonth] + " " + root.displayedYear
                }

                Repeater {
                    model: [{label: "PREV", offset: -1}, {label: "NEXT", offset: 1}]

                    Rectangle {
                        id: monthControl

                        required property var modelData
                        readonly property bool hovered: monthHover.hovered
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 48
                        border.color: hovered ? Services.Theme.accent : Services.Theme.border
                        border.width: 1
                        color: monthTap.pressed || hovered ? Services.Theme.surfaceAlt : "transparent"
                        radius: Services.RailGeometry.controlRadius
                        scale: monthTap.pressed ? 0.96 : 1

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

                        Text {
                            anchors.centerIn: parent
                            color: monthControl.hovered ? Services.Theme.accent : Services.Theme.muted
                            font.family: Services.Theme.monoFamily
                            font.pixelSize: 8
                            font.letterSpacing: 1
                            text: monthControl.modelData.label
                        }
                        HoverHandler {
                            id: monthHover
                        }
                        TapHandler {
                            id: monthTap

                            onTapped: root.changeMonth(monthControl.modelData.offset)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Services.Theme.border
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: root.weekdayNames

                    Text {
                        required property string modelData
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: 38
                        color: Services.Theme.muted
                        font.family: Services.Theme.monoFamily
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Repeater {
                    model: root.calendarDays

                    Rectangle {
                        id: dayCell

                        required property var modelData
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: 38
                        border.color: modelData.today ? Services.Theme.accent : Services.Theme.border
                        border.width: modelData.day > 0 ? 1 : 0
                        color: modelData.today ? Services.Theme.accent : "transparent"
                        opacity: modelData.day > 0 ? 1 : 0
                        radius: Services.RailGeometry.controlRadius

                        Text {
                            anchors.centerIn: parent
                            color: dayCell.modelData.today ? Services.Theme.background : Services.Theme.text
                            font.family: Services.Theme.monoFamily
                            font.pixelSize: 10
                            font.weight: dayCell.modelData.today ? Font.DemiBold : Font.Normal
                            text: dayCell.modelData.day > 0 ? dayCell.modelData.day : ""
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
            Components.FolioLabel {
                Layout.alignment: Qt.AlignRight
                text: "MONDAY / FIRST COLUMN"
            }
        }
    }
}
