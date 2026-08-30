import Quickshell
import QtQuick
import QtQuick.Window
import "../services" as Services

Item {
    id: root

    property color accentColor: Services.Theme.accent
    property color borderColor: Services.Theme.border
    property bool reducedMotion: Services.ShellState.reducedMotion
    property real phase: 0.17
    readonly property real devicePixelRatio: Math.max(1, Screen.devicePixelRatio)
    readonly property string sceneGraphBackend: String(Quickshell.env("QSG_RHI_BACKEND") || Quickshell.env("QT_QUICK_BACKEND") || "").toLowerCase()
    readonly property bool softwareBackend: sceneGraphBackend === "software"
    readonly property int shaderStatus: shader.status
    readonly property string shaderLog: shader.log
    readonly property bool shaderReady: shader.status === ShaderEffect.Compiled && !softwareBackend

    implicitHeight: Services.RailGeometry.dividerHeight
    visible: width > 0 && height > 0

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        visible: root.reducedMotion || !root.shaderReady

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0)
                position: 0
            }
            GradientStop {
                color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.64)
                position: 0.32
            }
            GradientStop {
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.48)
                position: 0.5
            }
            GradientStop {
                color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.64)
                position: 0.68
            }
            GradientStop {
                color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0)
                position: 1
            }
        }
    }

    ShaderEffect {
        id: shader

        property color accentColor: root.accentColor
        property color borderColor: root.borderColor
        property real devicePixelRatio: root.devicePixelRatio
        property size logicalSize: Qt.size(width, height)
        property real phase: root.phase

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/energy_connector.frag.qsb")
        visible: !root.reducedMotion && !root.softwareBackend

        onStatusChanged: {
            if (status === ShaderEffect.Error)
                console.warn("Infinity EnergyConnector shader unavailable: " + log);
        }
    }

    NumberAnimation on phase {
        duration: 12000
        from: 0.17
        loops: Animation.Infinite
        running: !root.reducedMotion && root.shaderReady
        to: 1.17
    }
}
