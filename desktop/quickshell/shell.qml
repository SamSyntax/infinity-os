import Quickshell
import QtQuick
import "surfaces"
import "services" as Services

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                required property var modelData
                property string activePanel: ""
                readonly property bool specialWorkspaceActive: Services.Workspaces.specialActiveForScreen(modelData)

                function togglePanel(panel) {
                    activePanel = activePanel === panel ? "" : panel;
                }

                function closePanels() {
                    activePanel = "";
                }

                onSpecialWorkspaceActiveChanged: {
                    if (specialWorkspaceActive)
                        closePanels();
                }

                WallpaperSurface {
                    screen: modelData
                }

                RailSurface {
                    id: rail
                    screen: modelData
                    visible: !specialWorkspaceActive
                    onAppearanceRequested: togglePanel("appearance")
                    onControlRequested: togglePanel("control")
                    onLauncherRequested: togglePanel("launcher")
                }

                ControlSurface {
                    id: controlSurface
                    anchorWindow: rail
                    panelVisible: !specialWorkspaceActive && activePanel === "control"
                    onDismissRequested: closePanels()
                }

                LauncherSurface {
                    id: launcherSurface
                    anchorWindow: rail
                    panelVisible: !specialWorkspaceActive && activePanel === "launcher"
                    onDismissRequested: closePanels()
                    onAppearanceRequested: activePanel = "appearance"
                }

                AppearanceSurface {
                    id: appearanceSurface
                    screen: modelData
                    panelVisible: !specialWorkspaceActive && activePanel === "appearance"
                    onDismissRequested: closePanels()
                }

                OsdSurface {
                    screen: modelData
                    shellVisible: !specialWorkspaceActive
                }
            }
        }
    }
}
