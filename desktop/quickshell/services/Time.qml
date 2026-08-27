pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property string clock: "--:--"
    property string date: "--- --"

    Process {
        id: clockProcess
        command: ["date", "+%H:%M|%a %d"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                root.clock = parts[0] || "--:--";
                root.date = parts[1] || "--- --";
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockProcess.running = true
    }
}
