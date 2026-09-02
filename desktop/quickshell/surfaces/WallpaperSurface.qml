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
    property string primaryWallpaperId: Services.Wallpaper.currentWallpaperId
    property string secondaryWallpaperId: ""
    property string primaryPendingId: ""
    property string secondaryPendingId: ""
    property string primaryPendingSource: ""
    property string secondaryPendingSource: ""
    property int wallpaperRequestGeneration: 0
    property int primaryLoadGeneration: -1
    property int secondaryLoadGeneration: -1
    readonly property string wallpaperPath: Quickshell.env("HOME") + "/.local/share/infinity-os/current-wallpaper.svg"
    readonly property string effectiveWallpaperPath: Services.Wallpaper.previewPath.length > 0 ? Services.Wallpaper.previewPath : wallpaperPath
    readonly property bool wallpaperMotionEnabled: !Services.ShellState.reducedMotion && Services.ShellState.motionScale > 0

    function wallpaperUrl(path) {
        return "file://" + path + "?revision=" + wallpaperRevision;
    }

    function refreshWallpaper(path, wallpaperId) {
        if (path.length === 0)
            return;
        wallpaperRevision += 1;
        wallpaperRequestGeneration += 1;
        const nextSource = wallpaperUrl(path);
        if (primaryActive) {
            secondaryPendingId = wallpaperId;
            secondaryPendingSource = nextSource;
            secondaryLoadGeneration = wallpaperRequestGeneration;
            secondaryWallpaper.source = nextSource;
        } else {
            primaryPendingId = wallpaperId;
            primaryPendingSource = nextSource;
            primaryLoadGeneration = wallpaperRequestGeneration;
            primaryWallpaper.source = nextSource;
        }
    }

    function activatePrimary() {
        if (primaryLoadGeneration !== wallpaperRequestGeneration || String(primaryWallpaper.source) !== primaryPendingSource)
            return;
        primaryWallpaperId = primaryPendingId;
        primaryActive = true;
    }

    function activateSecondary() {
        if (secondaryLoadGeneration !== wallpaperRequestGeneration || String(secondaryWallpaper.source) !== secondaryPendingSource)
            return;
        secondaryWallpaperId = secondaryPendingId;
        primaryActive = false;
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
        onStatusChanged: {
            if (status === Image.Ready)
                root.activatePrimary();
        }
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
        onStatusChanged: {
            if (status === Image.Ready)
                root.activateSecondary();
        }
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
        function onPreviewWallpaperChanged() {
            root.refreshWallpaper(root.effectiveWallpaperPath, Services.Wallpaper.effectiveWallpaperId);
        }
        function onCurrentWallpaperIdChanged() {
            if (Services.Wallpaper.previewWallpaper === null)
                root.refreshWallpaper(root.wallpaperPath, Services.Wallpaper.currentWallpaperId);
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
                root.refreshWallpaper(root.wallpaperPath, Services.Wallpaper.effectiveWallpaperId);
        }
    }

    Components.WallpaperArchiveTable {
        anchors.fill: parent
        opacity: root.primaryActive ? 1 : 0
        scale: root.primaryActive ? 1 : 1.035
        wallpaperId: root.primaryWallpaperId

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

    Components.WallpaperArchiveTable {
        anchors.fill: parent
        opacity: root.primaryActive ? 0 : 1
        scale: root.primaryActive ? 1.035 : 1
        wallpaperId: root.secondaryWallpaperId

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
        running: root.wallpaperMotionEnabled
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
            duration: Math.max(1, Math.round(9000 * Services.ShellState.motionScale))
            from: -1
            loops: Animation.Infinite
            running: root.wallpaperMotionEnabled
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
