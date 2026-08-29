pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    readonly property bool reducedMotion: settings.reducedMotion
    readonly property real motionScale: settings.motionScale
    property bool osdVisible: false
    property string osdLabel: "VOLUME"
    property real osdValue: 0.64

    function showOsd(label, value) {
        osdLabel = label;
        osdValue = Math.max(0, Math.min(1, value));
        osdVisible = true;
        osdTimer.restart();
    }

    function toggleReducedMotion() {
        settings.reducedMotion = !settings.reducedMotion;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/infinity-os/shell.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property bool reducedMotion: false
            property real motionScale: 1
        }
    }

    Timer {
        id: osdTimer
        interval: 1800
        onTriggered: osdVisible = false
    }
}
