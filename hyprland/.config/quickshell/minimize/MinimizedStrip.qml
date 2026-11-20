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
        visible: MinimizeState.entries.length > 0 || body.pieceW > 0
        anchors {
            top: true
            bottom: true
            right: true
        }
        implicitWidth: Theme.minimizeNames + Theme.minimizeRadius + Theme.spacing
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
            topEdge: ShellState.rightPanelEdge[win.name] ?? 0
            bottomEdge: ShellState.bottomPanelEdge[win.name] ?? 0
        }
    }
}
