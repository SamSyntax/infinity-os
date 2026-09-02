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
    property string device: ""
    property string gateway: ""
    property string gatewayState: "unavailable"
    property string transferState: "unavailable"
    property string packetLossState: "unavailable"
    property string latencyState: "unavailable"
    property real downBytesPerSecond: 0
    property real upBytesPerSecond: 0
    property real packetLossPercent: -1
    property real averageLatencyMs: -1
    property double previousRxBytes: -1
    property double previousTxBytes: -1
    property double previousSampleMs: 0
    property string gatewayRequestDevice: ""
    property string pingRequestDevice: ""
    property string pingRequestGateway: ""
    property int refreshGeneration: 0
    property int generalRequestGeneration: -1
    property int connectionRequestGeneration: -1
    property int probeGeneration: 0
    property int gatewayRequestGeneration: -1
    property int pingRequestGeneration: -1
    property bool probeRefreshPending: false

    readonly property bool probesAllowed: Quickshell.env("INFINITY_NESTED") !== "1"
    readonly property var parserEnvironment: ({ LC_ALL: "C", LANG: "C" })
    readonly property bool available: state !== "unavailable"
    readonly property bool connected: isConnectedState(state)
    readonly property string label: {
        if (!available)
            return "NET --";
        if (!connected)
            return "NET OFF";
        if (primaryType.indexOf("wireless") >= 0 || primaryType === "802-11-wireless")
            return "WIFI ON";
        if (primaryType.indexOf("ethernet") >= 0)
            return "LAN ON";
        return "NET ON";
    }

    function isConnectedState(candidate) {
        return candidate === "connected" || candidate === "connected (global)" || candidate === "connected (site only)" || candidate === "connected (local only)";
    }

    function isValidDevice(candidate) {
        return typeof candidate === "string" && candidate.length > 0 && candidate.length <= 15 && candidate[0] !== "-" && candidate !== "." && candidate !== ".." && /^[A-Za-z0-9_.-]+$/.test(candidate);
    }

    function isValidIpv4(candidate) {
        if (typeof candidate !== "string")
            return false;
        const octets = candidate.split(".");
        if (octets.length !== 4)
            return false;
        for (let index = 0; index < octets.length; index++) {
            if (!/^[0-9]{1,3}$/.test(octets[index]))
                return false;
            const value = Number(octets[index]);
            if (!Number.isFinite(value) || value < 0 || value > 255)
                return false;
        }
        return true;
    }

    function resetTransfer() {
        transferState = connected && isValidDevice(device) ? "measuring" : "unavailable";
        downBytesPerSecond = 0;
        upBytesPerSecond = 0;
        previousRxBytes = -1;
        previousTxBytes = -1;
        previousSampleMs = 0;
    }

    function resetProbe() {
        gateway = "";
        gatewayState = probesAllowed && connected && isValidDevice(device) ? "measuring" : "unavailable";
        packetLossState = probesAllowed && connected && isValidDevice(device) ? "measuring" : "unavailable";
        latencyState = probesAllowed && connected && isValidDevice(device) ? "measuring" : "unavailable";
        packetLossPercent = -1;
        averageLatencyMs = -1;
    }

    function clearConnection() {
        probeGeneration += 1;
        probeRefreshPending = false;
        primaryName = "";
        primaryType = "";
        device = "";
        if (gatewayProcess.running)
            gatewayProcess.running = false;
        if (pingProcess.running)
            pingProcess.running = false;
        resetTransfer();
        resetProbe();
    }

    function requestRefresh() {
        if (generalProcess.running || connectionProcess.running)
            return;
        refreshGeneration += 1;
        generalRequestGeneration = refreshGeneration;
        generalProcess.running = true;
    }

    function requestConnection(requestGeneration) {
        if (requestGeneration !== refreshGeneration || connectionProcess.running)
            return;
        connectionRequestGeneration = requestGeneration;
        connectionProcess.running = true;
    }

    function updateGeneral(output) {
        const fields = output.trim().split(":");
        if (fields.length < 2 || fields[0].length === 0) {
            state = "unavailable";
            connectivity = "unknown";
            clearConnection();
            return;
        }
        const nextState = fields[0];
        state = nextState;
        connectivity = fields[1].length > 0 ? fields[1] : "unknown";
        if (!isConnectedState(nextState))
            clearConnection();
    }

    function updateConnection(output, requestGeneration) {
        if (requestGeneration !== refreshGeneration || !connected)
            return;
        const lines = output.trim().split("\n");
        let fields = [];
        for (let index = 0; index < lines.length; index++) {
            const candidate = lines[index].split(":");
            if (candidate.length >= 2 && candidate[0] !== "loopback" && isValidDevice(candidate[1])) {
                fields = candidate;
                break;
            }
        }
        if (fields.length === 0) {
            if (connected)
                clearConnection();
            return;
        }

        const nextType = fields[0];
        const nextDevice = fields[1];
        if (!isValidDevice(nextDevice)) {
            clearConnection();
            return;
        }
        const nextName = fields.length > 2 ? fields.slice(2).join(":") : "";
        const interfaceChanged = nextDevice !== device;
        primaryType = nextType;
        primaryName = nextName;
        device = nextDevice;
        if (interfaceChanged) {
            probeGeneration += 1;
            probeRefreshPending = true;
            if (gatewayProcess.running)
                gatewayProcess.running = false;
            if (pingProcess.running)
                pingProcess.running = false;
            resetTransfer();
            resetProbe();
            Qt.callLater(startProbeCycle);
        }
    }

    function sampleTransfer() {
        if (!connected || !isValidDevice(device)) {
            resetTransfer();
            return;
        }
        rxFile.reload();
        txFile.reload();
        if (!rxFile.waitForJob() || !txFile.waitForJob()) {
            resetTransfer();
            transferState = "unavailable";
            return;
        }
        const rxBytes = Number(rxFile.text().trim());
        const txBytes = Number(txFile.text().trim());
        if (!Number.isFinite(rxBytes) || !Number.isFinite(txBytes)) {
            resetTransfer();
            transferState = "unavailable";
            return;
        }

        const sampleMs = Date.now();
        if (previousSampleMs > 0 && rxBytes >= previousRxBytes && txBytes >= previousTxBytes) {
            const elapsedSeconds = (sampleMs - previousSampleMs) / 1000;
            if (elapsedSeconds > 0) {
                downBytesPerSecond = (rxBytes - previousRxBytes) / elapsedSeconds;
                upBytesPerSecond = (txBytes - previousTxBytes) / elapsedSeconds;
                transferState = "available";
            }
        } else {
            transferState = "measuring";
        }
        previousRxBytes = rxBytes;
        previousTxBytes = txBytes;
        previousSampleMs = sampleMs;
    }

    function scheduleProbeCycle() {
        if (!root.probesAllowed) {
            resetProbe();
            return;
        }
        if (!connected || !isValidDevice(device))
            return;
        probeRefreshPending = true;
        startProbeCycle();
    }

    function startProbeCycle() {
        if (!root.probesAllowed) {
            probeRefreshPending = false;
            resetProbe();
            return;
        }
        if (!probeRefreshPending || !connected || !isValidDevice(device) || gatewayProcess.running || pingProcess.running)
            return;
        probeRefreshPending = false;
        gatewayRequestDevice = device;
        gatewayRequestGeneration = probeGeneration;
        gatewayProcess.command = ["/usr/bin/nmcli", "-g", "IP4.GATEWAY", "device", "show", gatewayRequestDevice];
        gatewayProcess.running = true;
    }

    function updateGateway(output, requestDevice, requestGeneration) {
        if (requestGeneration !== probeGeneration || requestDevice !== device || !isValidDevice(requestDevice))
            return;
        const nextGateway = output.trim().split("\n")[0];
        if (nextGateway.length === 0 || !isValidIpv4(nextGateway)) {
            resetProbe();
            gatewayState = "unavailable";
            packetLossState = "unavailable";
            latencyState = "unavailable";
            return;
        }
        if (nextGateway !== gateway) {
            gateway = nextGateway;
            packetLossPercent = -1;
            averageLatencyMs = -1;
        }
        gatewayState = "available";
        packetLossState = "measuring";
        latencyState = "measuring";
        requestPing(requestGeneration);
    }

    function requestPing(requestGeneration) {
        if (requestGeneration !== probeGeneration || !probesAllowed || !connected || !isValidDevice(device) || !isValidIpv4(gateway) || gatewayProcess.running || pingProcess.running)
            return;
        pingRequestDevice = device;
        pingRequestGateway = gateway;
        pingRequestGeneration = requestGeneration;
        packetLossState = "measuring";
        latencyState = "measuring";
        pingProcess.command = ["/usr/bin/ping", "-n", "-q", "-c", "3", "-W", "1", pingRequestGateway];
        pingProcess.running = true;
    }

    function updateProbe(output, requestDevice, requestGateway, requestGeneration) {
        if (requestGeneration !== probeGeneration || requestDevice !== device || requestGateway !== gateway || !isValidDevice(requestDevice) || !isValidIpv4(requestGateway))
            return;
        const lossMatch = output.match(/([0-9]+(?:\.[0-9]+)?)%\s+packet loss/);
        const latencyMatch = output.match(/=\s*[0-9.]+\/([0-9.]+)\//);
        if (lossMatch !== null) {
            packetLossPercent = Number(lossMatch[1]);
            packetLossState = Number.isFinite(packetLossPercent) ? "available" : "unavailable";
        } else {
            packetLossPercent = -1;
            packetLossState = "unavailable";
        }
        if (latencyMatch !== null) {
            averageLatencyMs = Number(latencyMatch[1]);
            latencyState = Number.isFinite(averageLatencyMs) ? "available" : "unavailable";
        } else {
            averageLatencyMs = -1;
            latencyState = "unavailable";
        }
    }

    FileView {
        id: rxFile

        blockLoading: true
        path: root.isValidDevice(root.device) ? "/sys/class/net/" + root.device + "/statistics/rx_bytes" : ""
        preload: false
        printErrors: false
    }

    FileView {
        id: txFile

        blockLoading: true
        path: root.isValidDevice(root.device) ? "/sys/class/net/" + root.device + "/statistics/tx_bytes" : ""
        preload: false
        printErrors: false
    }

    Process {
        id: generalProcess

        command: ["/usr/bin/nmcli", "--escape", "no", "-t", "-f", "STATE,CONNECTIVITY", "general"]
        environment: root.parserEnvironment
        stdout: StdioCollector {
            id: generalOutput
        }
        onExited: (exitCode, exitStatus) => {
            const requestGeneration = root.generalRequestGeneration;
            if (requestGeneration !== root.refreshGeneration)
                return;
            if (exitCode === 0) {
                root.updateGeneral(generalOutput.text);
                if (requestGeneration !== root.refreshGeneration)
                    return;
                if (root.connected)
                    root.requestConnection(requestGeneration);
            } else {
                root.state = "unavailable";
                root.connectivity = "unknown";
                root.clearConnection();
            }
        }
    }

    Process {
        id: connectionProcess

        command: ["/usr/bin/nmcli", "--escape", "no", "-t", "-f", "TYPE,DEVICE,NAME", "connection", "show", "--active"]
        environment: root.parserEnvironment
        stdout: StdioCollector {
            id: connectionOutput
        }
        onExited: (exitCode, exitStatus) => {
            const requestGeneration = root.connectionRequestGeneration;
            if (requestGeneration !== root.refreshGeneration)
                return;
            if (exitCode === 0)
                root.updateConnection(connectionOutput.text, requestGeneration);
            else
                root.clearConnection();
        }
    }

    Process {
        id: gatewayProcess

        environment: root.parserEnvironment
        stdout: StdioCollector {
            id: gatewayOutput
        }
        onExited: (exitCode, exitStatus) => {
            if (root.gatewayRequestGeneration !== root.probeGeneration || root.gatewayRequestDevice !== root.device) {
                root.startProbeCycle();
                return;
            }
            if (exitCode === 0) {
                root.updateGateway(gatewayOutput.text, root.gatewayRequestDevice, root.gatewayRequestGeneration);
            } else {
                root.resetProbe();
                root.gatewayState = "unavailable";
                root.packetLossState = "unavailable";
                root.latencyState = "unavailable";
            }
            root.startProbeCycle();
        }
    }

    Process {
        id: pingProcess

        environment: root.parserEnvironment
        stdout: StdioCollector {
            id: pingOutput
        }
        stderr: StdioCollector {
            id: pingError
        }
        onExited: (exitCode, exitStatus) => {
            root.updateProbe(pingOutput.text + "\n" + pingError.text, root.pingRequestDevice, root.pingRequestGateway, root.pingRequestGeneration);
            root.startProbeCycle();
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sampleTransfer()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.requestRefresh()
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.scheduleProbeCycle()
    }
}
