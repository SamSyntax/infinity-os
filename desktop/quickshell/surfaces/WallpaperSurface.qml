import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components" as Components
import "../services" as Services

PanelWindow {
    id: root
    color: Services.Theme.background
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    anchors { top: true; right: true; bottom: true; left: true }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/nocturne.svg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.local/share/infinity-os/current-wallpaper.svg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: Services.Theme.background
        opacity: 0.18
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 68
        anchors.bottomMargin: 52
        spacing: 5
        Components.FolioLabel { text: "INFINITY / FIELD NOTES" }
        Rectangle { width: 210; height: 1; color: Services.Theme.border }
        Components.FolioLabel { text: Services.Time.date }
    }
}
