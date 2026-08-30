import Quickshell
import QtQuick
import QtQuick.Window
import "../services" as Services

Item {
    id: root

    property color inkColor: Services.Theme.text
    property color shadowColor: Services.Theme.background
    property bool reducedMotion: Services.ShellState.reducedMotion
    property real phase: 0.31
    readonly property real devicePixelRatio: Math.max(1, Screen.devicePixelRatio)
    readonly property string sceneGraphBackend: String(Quickshell.env("QSG_RHI_BACKEND") || Quickshell.env("QT_QUICK_BACKEND") || "").toLowerCase()
    readonly property bool softwareBackend: sceneGraphBackend === "software"
    readonly property int shaderStatus: shader.status
    readonly property string shaderLog: shader.log
    readonly property bool shaderReady: shader.status === ShaderEffect.Compiled && !softwareBackend

    implicitWidth: 280
    implicitHeight: 280

    Item {
        anchors.fill: parent
        visible: root.reducedMotion || !root.shaderReady

        Rectangle {
            anchors.centerIn: parent
            border.color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.58)
            border.width: 1
            color: "transparent"
            height: Math.min(parent.width, parent.height) * 0.32
            radius: height / 2
            rotation: -7
            width: Math.min(parent.width, parent.height) * 0.74
        }

        Rectangle {
            anchors.centerIn: parent
            border.color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.24)
            border.width: 1
            color: "transparent"
            height: Math.min(parent.width, parent.height) * 0.48
            radius: width / 2
            width: height
        }

        Rectangle {
            anchors.centerIn: parent
            border.color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.18)
            border.width: 1
            color: root.shadowColor
            height: Math.min(parent.width, parent.height) * 0.30
            radius: width / 2
            width: height
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0)
                    position: 0.12
                }
                GradientStop {
                    color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.18)
                    position: 0.5
                }
                GradientStop {
                    color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0)
                    position: 0.88
                }
            }
        }
    }

    ShaderEffect {
        id: shader

        property real devicePixelRatio: root.devicePixelRatio
        property color inkColor: root.inkColor
        property size logicalSize: Qt.size(width, height)
        property real phase: root.phase
        property color shadowColor: root.shadowColor

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/archive_black_hole.frag.qsb")
        visible: !root.reducedMotion && !root.softwareBackend

        onStatusChanged: {
            if (status === ShaderEffect.Error)
                console.warn("Infinity ArchiveBlackHole shader unavailable: " + log);
        }
    }

    NumberAnimation on phase {
        duration: 18000
        from: 0.31
        loops: Animation.Infinite
        running: !root.reducedMotion && root.shaderReady
        to: 1.31
    }
}
