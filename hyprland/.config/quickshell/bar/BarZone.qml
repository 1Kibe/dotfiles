import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme

// The space the bar takes on its edge of one monitor (top or bottom,
// Configurações → Barra), reserved by an empty window: the frame (Bar.qml)
// takes the whole screen and must not push the windows, so it reserves
// nothing itself. Hyprland adds gaps_out after this zone. Nothing is drawn
// and nothing is clickable.
PanelWindow {
    required property var modelData
    screen: modelData

    anchors {
        top: !Theme.barAtBottom
        bottom: Theme.barAtBottom
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
