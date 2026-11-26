import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// The minimized windows' strip: one window per screen on its right edge,
// the screen's height (it never changes size), no exclusive zone, no
// keyboard, taking the mouse only on the piece (StripBody's hitItem).
// Each screen shows the windows that left it (MinimizeState.forMonitor).
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property string name: modelData.name
        readonly property bool hasBar: ShellState.barScreens.length === 0 || ShellState.barScreens.includes(name)

        screen: modelData
        visible: MinimizeState.forMonitor(name).length > 0 || body.pieceW > 0
        anchors {
            top: true
            bottom: true
            right: true
        }
        // Room for the open piece and the preview card beside it
        implicitWidth: Theme.minimizeNames + Theme.previewWidth + Theme.minimizeRadius + 2 * Theme.spacing
        exclusionMode: ExclusionMode.Ignore
        color: Theme.clear
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-minimize"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            item: body.hitItem
        }

        StripBody {
            id: body
            anchors.fill: parent
            screenName: win.name
            entries: MinimizeState.forMonitor(win.name)
            areaTop: win.hasBar && !Theme.barAtBottom ? Theme.barHeight : 0
            areaBottom: height - (win.hasBar && Theme.barAtBottom ? Theme.barHeight : 0)
            // A bar panel comes from the top, or from the bottom with the
            // bar there; the clipboard's drawer always from the bottom
            readonly property real panelEdge: ShellState.rightPanelEdge[win.name] ?? 0
            readonly property real drawerEdge: ShellState.bottomPanelEdge[win.name] ?? 0
            // Kept Theme.minimizePanelGap from the panel, so the tab's own
            // corner never runs into the panel's
            topEdge: Theme.barAtBottom || panelEdge <= 0 ? 0 : panelEdge + Theme.minimizePanelGap
            // Only a bar panel is closed for room, never for the drawer
            panelInTheWay: panelEdge > 0
            readonly property real panelBottomEdge: panelEdge - Theme.minimizePanelGap
            bottomEdge: Theme.barAtBottom && panelEdge > 0
                        ? (drawerEdge > 0 ? Math.min(panelBottomEdge, drawerEdge) : panelBottomEdge) : drawerEdge
        }
    }
}
