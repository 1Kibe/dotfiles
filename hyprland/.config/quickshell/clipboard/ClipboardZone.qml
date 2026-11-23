import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// The space the clipboard drawer takes on the bottom of one monitor while it
// shows, reserved by an empty window, like SettingsZone for the settings:
// the drawer's height; Hyprland adds gaps_out after it, so the gap to the
// windows is the same as on every other edge. With the bar on the bottom it
// stacks on the bar's zone, as the drawer sits on the bar. Shown from the
// start of the opening to the end of the closing (ShellState.clipboardOn),
// so the windows do not move back under a drawer still going down. Floating
// windows stay where they are.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    visible: modelData.name !== "" && ShellState.clipboardOn === modelData.name

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Theme.clipboardHeight
    exclusiveZone: Theme.clipboardHeight
    color: Theme.clear
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-clipboard-zone"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
