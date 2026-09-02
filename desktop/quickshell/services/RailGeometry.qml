pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property int outerGap: 14
    readonly property int topGap: 6
    readonly property int surfaceHeight: 34
    readonly property int exclusiveZone: topGap + surfaceHeight
    readonly property int surfaceRadius: surfaceHeight / 4
    readonly property int horizontalPadding: 7
    readonly property int controlHeight: surfaceHeight - 6
    readonly property int controlRadius: surfaceRadius - 3
    readonly property int controlHorizontalPadding: 6
    readonly property int controlVerticalPadding: 3
    readonly property int minimumControlWidth: 40
    readonly property int sectionSpacing: 5
    readonly property int workspaceSpacing: 2
    readonly property int dividerHeight: surfaceHeight / 2
    readonly property int brandWidth: 72
    readonly property int accentRuleWidth: 118
    readonly property int accentRuleInset: 10
    readonly property int workspaceActiveWidth: 27
    readonly property int workspaceWidth: 19
    readonly property int workspaceNarrowActiveWidth: 23
    readonly property int workspaceNarrowWidth: 16
    readonly property int networkControlWidth: 28
    readonly property int compactBreakpoint: 1480
    readonly property int narrowBreakpoint: 1120
    readonly property int brandMarkFontSize: 16
    readonly property int brandLabelFontSize: 7
    readonly property int telemetryFontSize: 7
    readonly property int clockFontSize: 11
    readonly property int workspaceFontSize: 6
    readonly property int controlIndexFontSize: 6
    readonly property int controlLabelFontSize: 7
}
