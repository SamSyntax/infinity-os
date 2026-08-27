pragma Singleton

import Quickshell
import QtQuick

Singleton {
    property bool reducedMotion: false
    property bool osdVisible: false
    property string osdLabel: "VOLUME"
    property real osdValue: 0.64

    function showOsd(label, value) {
        osdLabel = label;
        osdValue = Math.max(0, Math.min(1, value));
        osdVisible = true;
        osdTimer.restart();
    }

    Timer {
        id: osdTimer
        interval: 1800
        onTriggered: osdVisible = false
    }
}
