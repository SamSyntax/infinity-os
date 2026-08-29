import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../components" as Components
import "../services" as Services

PanelWindow {
    id: root
    property bool primaryActive: true
    property int grainFrame: 0
    property int wallpaperRevision: 0
    readonly property string wallpaperPath: Quickshell.env("HOME") + "/.local/share/infinity-os/current-wallpaper.svg"
    readonly property string effectiveWallpaperPath: Services.Wallpaper.previewPath.length > 0 ? Services.Wallpaper.previewPath : wallpaperPath

    function wallpaperUrl(path) {
        return "file://" + path + "?revision=" + wallpaperRevision;
    }

    function refreshWallpaper(path) {
        if (path.length === 0)
            return;
        wallpaperRevision += 1;
        if (primaryActive) {
            secondaryWallpaper.source = wallpaperUrl(path);
        } else {
            primaryWallpaper.source = wallpaperUrl(path);
        }
        primaryActive = !primaryActive;
    }

    color: Services.Theme.background
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/nocturne.svg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Image {
        id: primaryWallpaper
        anchors.fill: parent
        source: wallpaperFile.loaded ? root.wallpaperUrl(root.wallpaperPath) : Qt.resolvedUrl("../assets/nocturne.svg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: root.primaryActive ? 1 : 0
        scale: root.primaryActive ? 1 : 1.035
        Behavior on opacity {
            NumberAnimation {
                duration: Services.Theme.duration * 2
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Services.Theme.duration * 3
                easing.type: Easing.OutCubic
            }
        }
    }

    Image {
        id: secondaryWallpaper
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: root.primaryActive ? 0 : 1
        scale: root.primaryActive ? 1.035 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Services.Theme.duration * 2
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Services.Theme.duration * 3
                easing.type: Easing.OutCubic
            }
        }
    }

    Connections {
        target: Services.Wallpaper
        function onPreviewPathChanged() {
            root.refreshWallpaper(root.effectiveWallpaperPath);
        }
    }

    FileView {
        id: wallpaperFile
        path: root.wallpaperPath
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload();
            if (Services.Wallpaper.previewPath.length === 0)
                root.refreshWallpaper(root.wallpaperPath);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Services.Theme.background
        opacity: 0.18
    }

    Canvas {
        id: grain
        anchors.fill: parent
        opacity: 0.13

        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            let seed = 7919 + root.grainFrame * 104729;
            function random() {
                seed = (seed * 16807) % 2147483647;
                return seed / 2147483647;
            }
            const count = Math.max(1800, Math.round(width * height / 470));
            for (let index = 0; index < count; index++) {
                const alpha = 0.08 + random() * 0.2;
                context.fillStyle = random() > 0.54 ? "rgba(238,233,220," + alpha + ")" : "rgba(6,7,9," + alpha + ")";
                const size = random() > 0.9 ? 2 : 1;
                context.fillRect(Math.floor(random() * width), Math.floor(random() * height), size, size);
            }
        }
    }

    Timer {
        interval: 140
        repeat: true
        running: !Services.ShellState.reducedMotion
        onTriggered: {
            root.grainFrame += 1;
            grain.requestPaint();
        }
    }

    Rectangle {
        id: scanline
        color: Services.Theme.accent
        height: 1
        opacity: 0.08
        width: parent.width
        y: -1

        NumberAnimation on y {
            duration: Services.ShellState.reducedMotion ? 0 : 9000
            from: -1
            loops: Animation.Infinite
            running: !Services.ShellState.reducedMotion
            to: root.height
        }
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 68
        anchors.bottomMargin: 52
        spacing: 5
        Components.FolioLabel {
            text: "INFINITY / FIELD NOTES"
        }
        Rectangle {
            width: 210
            height: 1
            color: Services.Theme.border
        }
        Components.FolioLabel {
            text: Services.Time.date
        }
    }
}
