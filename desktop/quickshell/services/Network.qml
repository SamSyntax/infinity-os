pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string state: "unavailable"
    property string connectivity: "unknown"
    property string primaryName: ""
    property string primaryType: ""
    readonly property bool available: state !== "unavailable"
    readonly property bool connected: state === "connected" || state === "connected (global)" || state === "connected (local only)"
    readonly property string label: {
        if (!available)
            return "NET --";
        if (!connected)
            return "NET OFF";
        const prefix = primaryType.indexOf("wireless") >= 0 || primaryType === "802-11-wireless" ? "WIFI" : (primaryType.indexOf("ethernet") >= 0 ? "LAN" : "NET");
        return primaryName.length > 0 ? prefix + " " + primaryName : prefix + " ON";
    }

    function updateGeneral(output) {
        const fields = output.trim().split(":");
        if (fields.length < 2 || fields[0].length === 0) {
            state = "unavailable";
            connectivity = "unknown";
            return;
        }
        state = fields[0];
        connectivity = fields[1];
    }

    function updateConnection(output) {
        const firstLine = output.trim().split("\n")[0];
        const fields = firstLine.split(":");
        primaryType = fields.length > 0 ? fields[0] : "";
        primaryName = fields.length > 2 ? fields.slice(2).join(":") : "";
    }

    Process {
        id: generalProcess
        command: ["/usr/bin/nmcli", "-t", "-f", "STATE,CONNECTIVITY", "general"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateGeneral(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.state = "unavailable";
        }
    }

    Process {
        id: connectionProcess
        command: ["/usr/bin/nmcli", "-t", "-f", "TYPE,DEVICE,NAME", "connection", "show", "--active"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateConnection(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.primaryName = "";
                root.primaryType = "";
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            if (!generalProcess.running)
                generalProcess.running = true;
            if (!connectionProcess.running)
                connectionProcess.running = true;
        }
    }
}
