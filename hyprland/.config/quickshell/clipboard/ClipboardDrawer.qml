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
// keyboard while open. Locked, it never opens, and closes if open.
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
    // With the bar on the bottom edge, the drawer sits on the bar
    margins.bottom: Theme.barAtBottom ? Theme.barHeight : 0
    implicitHeight: Theme.clipboardHeight
    // Never pushes windows aside, and covers what is under it
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

    DrawerBody {
        id: drawer
        anchors.fill: parent
        progress: root.progress
    }
}
