pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property bool available: Hyprland.requestSocketPath.length > 0
    readonly property var workspaceIds: {
        const ids = {};
        const workspaces = Hyprland.workspaces.values;
        for (let index = 0; index < workspaces.length; index++) {
            const workspace = workspaces[index];
            if (workspace.id > 0)
                ids[workspace.id] = true;
        }
        for (let id = 1; id <= 5; id++)
            ids[id] = true;
        return Object.keys(ids).map(Number).sort((left, right) => left - right);
    }

    function monitorForScreen(screen) {
        return screen === null ? null : Hyprland.monitorFor(screen);
    }

    function activeWorkspaceIdForScreen(screen) {
        const monitor = monitorForScreen(screen);
        return monitor === null || monitor.activeWorkspace === null ? -1 : monitor.activeWorkspace.id;
    }

    function occupied(workspaceId) {
        const workspaces = Hyprland.workspaces.values;
        for (let index = 0; index < workspaces.length; index++) {
            if (workspaces[index].id === workspaceId)
                return true;
        }
        return false;
    }

    function activate(workspaceId) {
        if (!Number.isInteger(workspaceId) || workspaceId < 1)
            return;
        Hyprland.dispatch("workspace " + workspaceId);
    }

    function specialActiveForScreen(screen) {
        const monitor = monitorForScreen(screen);
        if (monitor === null || monitor.lastIpcObject === null)
            return false;
        const special = monitor.lastIpcObject.specialWorkspace;
        return special !== undefined && special !== null && Number(special.id) !== 0 && String(special.name).length > 0;
    }

    Timer {
        interval: 600
        repeat: true
        running: true
        onTriggered: Hyprland.refreshMonitors()
    }
}
