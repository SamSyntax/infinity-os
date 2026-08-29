pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool available: false
    property bool muted: false
    property real outputLevel: 0
    property real queuedLevel: -1
    property bool setting: false
    property string error: ""
    readonly property string label: available ? (muted ? "MUTED" : Math.round(outputLevel * 100) + "%") : "--"

    function update(output) {
        const match = output.match(/Volume:\s+([0-9.]+)/);
        if (match === null) {
            available = false;
            return;
        }
        const parsed = Number(match[1]);
        if (!Number.isFinite(parsed)) {
            available = false;
            return;
        }
        outputLevel = Math.max(0, Math.min(1, parsed));
        muted = output.indexOf("[MUTED]") >= 0;
        available = true;
        error = "";
    }

    function setOutputLevel(value) {
        queuedLevel = Math.max(0, Math.min(1, value));
        if (!setProcess.running)
            applyQueuedLevel();
    }

    function applyQueuedLevel() {
        if (queuedLevel < 0 || setProcess.running)
            return;
        const level = queuedLevel;
        queuedLevel = -1;
        outputLevel = level;
        setting = true;
        setProcess.command = ["/usr/bin/wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(level * 100) + "%"];
        setProcess.running = true;
    }

    Process {
        id: readProcess
        command: ["/usr/bin/wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.update(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.available = false;
        }
    }

    Process {
        id: setProcess
        onExited: (exitCode, exitStatus) => {
            root.setting = false;
            if (exitCode !== 0)
                root.error = "Unable to update output volume";
            if (root.queuedLevel >= 0)
                root.applyQueuedLevel();
            else if (!readProcess.running)
                readProcess.running = true;
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (!root.setting && !readProcess.running)
                readProcess.running = true;
        }
    }
}
