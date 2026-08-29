pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var catalog: []
    property bool applying: false
    property string applyError: ""
    property string pendingWallpaperId: ""
    property var previewWallpaper: null
    readonly property string assetRoot: Quickshell.env("INFINITY_SOURCE_ROOT") || Quickshell.env("HOME") + "/.local/share/infinity-os/runtime"
    readonly property string currentWallpaperId: stateAdapter.wallpaperId
    readonly property string previewPath: previewWallpaper === null ? "" : assetRoot + "/" + previewWallpaper.path

    signal applySucceeded(string wallpaperId)

    function preview(wallpaper) {
        previewWallpaper = wallpaper;
        applyError = "";
    }

    function clearPreview() {
        previewWallpaper = null;
    }

    function apply(wallpaperId) {
        if (applying || wallpaperId.length === 0)
            return;
        pendingWallpaperId = wallpaperId;
        applyError = "";
        applying = true;
        applyProcess.command = [Theme.commandPath, "wallpaper", wallpaperId, "--target-user", Quickshell.env("USER")];
        applyProcess.running = true;
    }

    Process {
        id: catalogProcess
        command: [Theme.commandPath, "wallpapers", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.catalog = JSON.parse(text);
                } catch (error) {
                    root.applyError = "Wallpaper catalog is invalid: " + error;
                }
            }
        }
        stderr: StdioCollector {
            id: catalogError
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.applyError = catalogError.text.trim() || "Unable to load wallpaper catalog";
        }
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            id: applyOutput
        }
        stderr: StdioCollector {
            id: applyFailure
        }
        onExited: (exitCode, exitStatus) => {
            root.applying = false;
            if (exitCode === 0) {
                stateFile.reload();
                root.clearPreview();
                const appliedWallpaperId = root.pendingWallpaperId;
                root.pendingWallpaperId = "";
                root.applySucceeded(appliedWallpaperId);
            } else {
                root.clearPreview();
                root.pendingWallpaperId = "";
                root.applyError = applyFailure.text.trim() || applyOutput.text.trim() || "Wallpaper apply failed";
            }
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/share/infinity-os/wallpaper.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: stateAdapter
            property string wallpaperId: "nocturne"
            property string title: "Nocturne Index"
        }
    }
}
