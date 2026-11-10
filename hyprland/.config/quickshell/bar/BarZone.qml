import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme

// The space the bar takes at the top of one monitor, reserved by an empty
// window: the frame (Bar.qml) grows down while a panel is open and must not
// push the windows, so it reserves nothing itself. Hyprland adds gaps_out
// below this zone. Nothing is drawn and nothing is clickable.
PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: Theme.clear
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-bar-zone"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
