import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.state

// The space the settings take on the left of one monitor while they show,
// reserved by an empty window, like BarZone for the bar: the panel's width;
// Hyprland adds gaps_out after it, so the gap to the windows is the same as
// on every other edge (Ryan, 2026-11-10: with the concave corner added too
// the gap was doubled). The concave corner reaches past the width only on
// the bar's line (y 30) and is back at the width ~13 px lower, above where
// the windows start (bar + gaps_out), so it never covers one. Shown from the
// start of the opening to the end of the closing (ShellState.settingsOn),
// so the windows do not move back under a panel still sliding out.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
    readonly property string monitorName: hyprMonitor ? hyprMonitor.name : ""

    readonly property int zone: Theme.settingsWidth

    visible: monitorName !== "" && ShellState.settingsOn === monitorName

    anchors {
        top: true
        bottom: true
        left: true
    }
    implicitWidth: zone
    exclusiveZone: zone
    color: Theme.clear
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-settings-zone"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
