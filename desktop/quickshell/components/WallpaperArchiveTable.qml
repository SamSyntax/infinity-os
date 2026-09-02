pragma ComponentBehavior: Bound

import QtQuick
import "../services" as Services

Item {
    id: root

    property string wallpaperId: "nocturne"
    readonly property var table: tableForWallpaper(wallpaperId)
    readonly property real cropScale: Math.max(width / 1600, height / 900)
    readonly property real cropOffsetX: (width - 1600 * cropScale) / 2
    readonly property real cropOffsetY: (height - 900 * cropScale) / 2
    readonly property bool motionEnabled: root.opacity > 0 && !Services.ShellState.reducedMotion && Services.ShellState.motionScale > 0 && Services.Theme.duration > 0
    readonly property int rowDuration: Math.max(1, Services.Theme.duration * 8)

    function tableForWallpaper(id) {
        const tables = {
            "aurora": {
                x: 72, firstBaseline: 330, spacing: 44, width: 676,
                background: "#eee7d8", labelColor: "#8a745f", valueColor: "#28251f", separatorColor: "#cfc4af",
                rows: [["STOCK", "UNCOATED / IVORY"], ["DENSITY", "72 LPI"], ["OFFSET", "+04 / -11"], ["REGISTER", "OPEN"]]
            },
            "cobalt-relay": {
                x: 72, firstBaseline: 330, spacing: 44, width: 666,
                background: "#0b1020", labelColor: "#8790a9", valueColor: "#e5e7ee", separatorColor: "#29334f",
                rows: [["VECTOR", "C-61"], ["AZIMUTH", "318°"], ["DEPTH", "-42 DB"], ["STATUS", "DORMANT"]]
            },
            "ember-index": {
                x: 72, firstBaseline: 330, spacing: 44, width: 670,
                background: "#120d0b", labelColor: "#9c7460", valueColor: "#ead8c4", separatorColor: "#432b23",
                rows: [["CORE", "E-09"], ["HEAT", "642 K"], ["OXIDE", "FERROUS"], ["DECAY", "0.031 / H"]]
            },
            "nocturne": {
                x: 72, firstBaseline: 330, spacing: 44, width: 664,
                background: "#070a10", labelColor: "#74869a", valueColor: "#e0e7ef", separatorColor: "#263447",
                rows: [["CHANNEL", "N-17"], ["PHASE", "LOCKED"], ["LATENCY", "08.42 MS"], ["CARRIER", "118.7 KHZ"]]
            },
            "signal-archive": {
                x: 74, firstBaseline: 310, spacing: 42, width: 664,
                background: "#090909", labelColor: "#817d75", valueColor: "#d8d3c8", separatorColor: "#34322f",
                rows: [["FIELD", "ABSTRACT FORM"], ["MATERIAL", "DIGITAL PAPER"], ["PROCESS", "HALFTONE / DISPLACE"], ["SIGNAL", "41.82 KHZ"], ["STATE", "STABLE"]]
            },
            "verdigris-ledger": {
                x: 72, firstBaseline: 330, spacing: 44, width: 666,
                background: "#07110e", labelColor: "#779284", valueColor: "#dce5db", separatorColor: "#254038",
                rows: [["SAMPLE", "V-23"], ["GROWTH", "STABLE"], ["COPPER", "18.4%"], ["MOISTURE", "42 RH"]]
            }
        };
        return tables[id] || tables.nocturne;
    }

    Item {
        x: root.cropOffsetX
        y: root.cropOffsetY
        width: 1600
        height: 900
        scale: root.cropScale
        transformOrigin: Item.TopLeft

        Rectangle {
            x: root.table.x
            y: root.table.firstBaseline - 14
            width: root.table.width
            height: (root.table.rows.length - 1) * root.table.spacing + 30
            color: root.table.background
        }

        Repeater {
            model: root.table.rows

            Item {
                id: rowVisual

                required property var modelData
                required property int index
                x: root.table.x
                y: root.table.firstBaseline + index * root.table.spacing - 14
                width: root.table.width
                height: root.table.spacing

                transform: Translate {
                    id: rowDrift
                }

                Text {
                    id: labelText

                    y: 14 - baselineOffset
                    color: root.table.labelColor
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 12
                    text: rowVisual.modelData[0]
                    textFormat: Text.PlainText
                }
                Text {
                    id: valueText

                    x: rowVisual.width - implicitWidth
                    y: 14 - baselineOffset
                    color: root.table.valueColor
                    font.family: Services.Theme.monoFamily
                    font.pixelSize: 12
                    text: rowVisual.modelData[1]
                    textFormat: Text.PlainText
                }
                Rectangle {
                    y: 29
                    width: parent.width
                    height: 1
                    color: root.table.separatorColor
                }

                SequentialAnimation {
                    id: rowPulse

                    loops: Animation.Infinite
                    running: root.motionEnabled

                    onRunningChanged: {
                        if (!running) {
                            rowDrift.x = 0;
                            rowVisual.opacity = 1;
                        }
                    }

                    PauseAnimation {
                        duration: rowVisual.index * Math.max(1, Services.Theme.duration / 2)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: rowDrift
                            property: "x"
                            from: 0
                            to: 6
                            duration: root.rowDuration
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: rowVisual
                            property: "opacity"
                            from: 1
                            to: 0.76
                            duration: root.rowDuration
                            easing.type: Easing.InOutSine
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: rowDrift
                            property: "x"
                            from: 6
                            to: 0
                            duration: root.rowDuration
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: rowVisual
                            property: "opacity"
                            from: 0.76
                            to: 1
                            duration: root.rowDuration
                            easing.type: Easing.InOutSine
                        }
                    }
                    PauseAnimation {
                        duration: Math.max(1, Services.Theme.duration * 3 - rowVisual.index * Math.max(1, Services.Theme.duration / 2))
                    }
                }
            }
        }
    }
}
