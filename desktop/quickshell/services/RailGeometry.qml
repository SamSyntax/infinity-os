pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property int outerGap: 18
    readonly property int topGap: 8
    readonly property int surfaceHeight: 40
    readonly property int exclusiveZone: topGap + surfaceHeight
    readonly property int surfaceRadius: surfaceHeight / 4
    readonly property int horizontalPadding: 8
    readonly property int controlHeight: surfaceHeight - 8
    readonly property int controlRadius: surfaceRadius - 4
    readonly property int controlHorizontalPadding: 7
    readonly property int controlVerticalPadding: 4
    readonly property int minimumControlWidth: 44
    readonly property int sectionSpacing: 6
    readonly property int workspaceSpacing: 2
    readonly property int dividerHeight: surfaceHeight / 2
    readonly property int brandWidth: 78
    readonly property int accentRuleWidth: 132
    readonly property int accentRuleInset: 12
    readonly property int workspaceActiveWidth: 30
    readonly property int workspaceWidth: 21
    readonly property int workspaceNarrowActiveWidth: 25
    readonly property int workspaceNarrowWidth: 17
    readonly property int networkMaxWidth: 112
    readonly property int networkNarrowMaxWidth: 72
    readonly property int compactBreakpoint: 1480
    readonly property int narrowBreakpoint: 1120
    readonly property int brandMarkFontSize: 18
    readonly property int brandLabelFontSize: 8
    readonly property int telemetryFontSize: 8
    readonly property int clockFontSize: 12
    readonly property int workspaceFontSize: 7
    readonly property int controlIndexFontSize: 7
    readonly property int controlLabelFontSize: 8
}
