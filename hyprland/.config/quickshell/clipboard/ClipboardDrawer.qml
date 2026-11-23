import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.state

// Super+V: the clipboard as a drawer on the focused monitor. It rises from
// the screen's bottom edge to its place, the screen's whole width (its top
// corners square, where it meets the screen's edges; only a thin line on
// top), and goes back down to close. With the bar on the bottom edge it
// rises from the bar's top. The screen is not dimmed: a click outside the
// drawer, Esc with the search empty, or Super+V again close it. It takes the
// keyboard while open. The windows on its monitor make room for it
// (ClipboardZone), as for the settings. Locked, it never opens, and closes
// if open.
// The tabs (Clipboard, Emoji, Anotações) are ClipStrip's, one height for
// all of them (Theme.clipboardHeight).
PanelWindow {
    id: root

    readonly property bool locked: LockState.locked || LockState.wanted
    readonly property bool shown: ClipboardStore.open && !locked
    // 0 = down out of the screen, 1 = in place; reduce motion: the fade
    property real progress: shown ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: Theme.dur(root.shown ? Theme.motionPanelOpen : Theme.motionPanelClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? Theme.curveDecel : Theme.curveAccel
        }
    }
    // The monitor Super+V was pressed on; the first one if it is gone
    screen: Quickshell.screens.find(s => s.name === ClipboardStore.openOn) ?? Quickshell.screens[0]
    visible: shown || progress > 0
    anchors {
        bottom: true
        left: true
        right: true
    }
    // With the bar on the bottom edge, the drawer sits on the bar (on a
    // screen that shows the bar: "Mostrar a barra em")
    readonly property bool barHere: screen !== null && (ShellState.barScreens.length === 0
                                                        || ShellState.barScreens.includes(screen.name))
    readonly property real bottomGap: Theme.barAtBottom && barHere ? Theme.barHeight : 0
    margins.bottom: bottomGap
    implicitHeight: Theme.clipboardHeight
    // Placed on the screen's edge (or the bar) whatever the zones; the
    // windows are pushed up by ClipboardZone, not by the drawer itself
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    // Exclusive so every key reaches the search; dropped as soon as it
    // starts closing, so the keyboard goes back at once
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Only the part of the body on the screen takes clicks, and nothing
    // while it closes (with reduce motion it stays in place while it fades)
    mask: Region {
        item: root.shown ? drawer.hit : nothing
    }
    Item {
        id: nothing
    }

    onShownChanged: {
        if (shown)
            drawer.strip.reset()
    }
    // The monitor where the drawer shows (opening, open or closing), for
    // ClipboardZone: the windows there make room for it
    readonly property string zoneOn: visible && screen ? screen.name : ""
    onZoneOnChanged: ShellState.clipboardOn = zoneOn
    // Locked while open: closed (the store too, so Super+V starts clean)
    onLockedChanged: {
        if (locked && ClipboardStore.open)
            ClipboardStore.close()
    }

    // A click outside the drawer closes it
    HyprlandFocusGrab {
        id: grab
        active: root.shown
        windows: [root]
        onCleared: {
            if (ClipboardStore.open)
                ClipboardStore.close()
        }
    }

    // The minimized windows' strip on the right edge slides up out of the
    // drawer's way: while it shows, the y of its top edge on the screen
    // (following the rise and the way down) goes to
    // ShellState.bottomPanelEdge, as this drawer's own; zero once hidden
    readonly property string edgeOn: screen ? screen.name : ""
    readonly property real stripEdge: visible && screen && drawer.hit.height > 0
        ? Math.round(screen.height - bottomGap - drawer.hit.height) : 0
    property string publishedOn: ""
    function publishEdge() {
        if (publishedOn !== "" && publishedOn !== edgeOn)
            ShellState.setBottomPanelEdge(publishedOn, 0, "clipboard")
        publishedOn = stripEdge > 0 ? edgeOn : ""
        if (edgeOn !== "")
            ShellState.setBottomPanelEdge(edgeOn, stripEdge, "clipboard")
    }
    onStripEdgeChanged: publishEdge()
    onEdgeOnChanged: publishEdge()
    // Gone (a reload, the screen removed): neither the zone nor the edge
    // stays behind
    Component.onDestruction: {
        if (ShellState.clipboardOn === zoneOn)
            ShellState.clipboardOn = ""
        if (publishedOn !== "")
            ShellState.setBottomPanelEdge(publishedOn, 0, "clipboard")
    }

    DrawerBody {
        id: drawer
        anchors.fill: parent
        progress: root.progress
    }
}
