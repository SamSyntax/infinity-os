import Quickshell
import QtQuick
import "surfaces"

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                required property var modelData

                WallpaperSurface {
                    screen: modelData
                }

                RailSurface {
                    id: rail
                    screen: modelData
                    onControlRequested: controlSurface.visible = !controlSurface.visible
                    onLauncherRequested: launcherSurface.visible = !launcherSurface.visible
                    onThemesRequested: themeSurface.visible = !themeSurface.visible
                }

                ControlSurface {
                    id: controlSurface
                    anchorWindow: rail
                }

                LauncherSurface {
                    id: launcherSurface
                    anchorWindow: rail
                }

                ThemeSurface {
                    id: themeSurface
                    anchorWindow: rail
                }

                OsdSurface {
                    screen: modelData
                }
            }
        }
    }
}
