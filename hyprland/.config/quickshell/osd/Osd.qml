import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// The notice in the middle of the focused monitor (state/OsdState says
// what and when; OsdBox draws it). No input at all (an empty mask), no
// keyboard, no reserved space; mapped only while it shows or fades. Locked
// or asked to lock, it is gone at once.
PanelWindow {
    id: root

    readonly property bool shown: OsdState.shown

    screen: Quickshell.screens.find(s => s.name === OsdState.monitor) ?? Quickshell.screens[0]
    // A quick print going on: out of the picture
    visible: (shown || (box.fading && !OsdState.locked)) && !CaptureState.printing
    onVisibleChanged: ShellState.setOverlay("osd", visible)
    // No anchors: the compositor centres it
    implicitWidth: Theme.osdSize
    implicitHeight: Theme.osdSize
    exclusionMode: ExclusionMode.Ignore
    color: Theme.clear
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-osd"

    OsdBox {
        id: box
        anchors.centerIn: parent
        shown: root.shown
    }
}
