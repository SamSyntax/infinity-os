pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool available: false
    property bool hasBattery: false
    property int percentage: -1
    property string batteryState: "unknown"
    property string profile: "unknown"
    readonly property bool charging: batteryState === "charging" || batteryState === "fully-charged"
    readonly property string label: !available ? "PWR --" : (!hasBattery ? "AC" : "BAT " + percentage + "%" + (charging ? "+" : ""))

    function updateBattery(output) {
        let present = false;
        let parsedPercentage = -1;
        let parsedState = "unknown";
        const lines = output.split("\n");
        for (let index = 0; index < lines.length; index++) {
            const separator = lines[index].indexOf(":");
            if (separator < 0)
                continue;
            const key = lines[index].slice(0, separator).trim();
            const value = lines[index].slice(separator + 1).trim();
            if (key === "present")
                present = value === "yes";
            else if (key === "percentage")
                parsedPercentage = Number(value.replace("%", ""));
            else if (key === "state")
                parsedState = value;
        }
        available = true;
        hasBattery = present && Number.isFinite(parsedPercentage) && parsedPercentage >= 0;
        percentage = hasBattery ? Math.max(0, Math.min(100, Math.round(parsedPercentage))) : -1;
        batteryState = parsedState;
    }

    Process {
        id: batteryProcess
        command: ["/usr/bin/upower", "-i", "/org/freedesktop/UPower/devices/DisplayDevice"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateBattery(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.available = false;
                root.hasBattery = false;
                root.percentage = -1;
            }
        }
    }

    Process {
        id: profileProcess
        command: ["/usr/bin/powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.profile = text.trim().length > 0 ? text.trim() : "unknown"
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.profile = "unknown";
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: {
            if (!batteryProcess.running)
                batteryProcess.running = true;
            if (!profileProcess.running)
                profileProcess.running = true;
        }
    }
}
