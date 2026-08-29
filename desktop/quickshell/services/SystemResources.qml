pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuLoad: -1
    property real memoryUsed: -1
    property real previousCpuIdle: -1
    property real previousCpuTotal: -1
    readonly property bool available: cpuLoad >= 0 || memoryUsed >= 0
    readonly property string cpuLabel: cpuLoad < 0 ? "CPU --" : "CPU " + Math.round(cpuLoad * 100) + "%"
    readonly property string memoryLabel: memoryUsed < 0 ? "MEM --" : "MEM " + Math.round(memoryUsed * 100) + "%"

    function updateCpu(output) {
        const firstLine = output.trim().split("\n")[0];
        const fields = firstLine.split(/\s+/);
        if (fields.length < 8 || fields[0] !== "cpu") {
            cpuLoad = -1;
            return;
        }
        const values = fields.slice(1).map(Number);
        if (values.some(value => !Number.isFinite(value))) {
            cpuLoad = -1;
            return;
        }
        const idle = values[3] + values[4];
        const total = values.reduce((sum, value) => sum + value, 0);
        if (previousCpuTotal >= 0 && total > previousCpuTotal) {
            const totalDelta = total - previousCpuTotal;
            const idleDelta = idle - previousCpuIdle;
            cpuLoad = Math.max(0, Math.min(1, 1 - idleDelta / totalDelta));
        }
        previousCpuIdle = idle;
        previousCpuTotal = total;
    }

    function updateMemory(output) {
        let total = -1;
        let available = -1;
        const lines = output.split("\n");
        for (let index = 0; index < lines.length; index++) {
            const parts = lines[index].trim().split(/\s+/);
            if (parts[0] === "MemTotal:")
                total = Number(parts[1]);
            else if (parts[0] === "MemAvailable:")
                available = Number(parts[1]);
        }
        memoryUsed = total > 0 && available >= 0 ? Math.max(0, Math.min(1, 1 - available / total)) : -1;
    }

    Process {
        id: cpuProcess
        command: ["/usr/bin/cat", "/proc/stat"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateCpu(text)
        }
    }

    Process {
        id: memoryProcess
        command: ["/usr/bin/cat", "/proc/meminfo"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateMemory(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!cpuProcess.running)
                cpuProcess.running = true;
            if (!memoryProcess.running)
                memoryProcess.running = true;
        }
    }
}
