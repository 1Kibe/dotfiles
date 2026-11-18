import QtQuick
import qs.theme
import qs.state
import qs.bar

// The control center's button at the end of the bar: the Arch symbol, which
// drops the control center down (Super+I, F9). Open, it takes the veil of
// the active items and the symbol lights up in the accent.
BarItem {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    readonly property string monitorName: monitor ? monitor.name : ""
    // ShellState is shared with the keybinds, so a center opened by Super+I
    // shows here as open too
    readonly property bool open: ShellState.controlOpen(monitorName)

    // nf-linux-archlinux of the Nerd Font
    text: String.fromCodePoint(0xF303)
    textColor: open ? Theme.accentLight : Theme.text
    tooltip: open ? "" : "Super+I"
    onClicked: ShellState.toggle("control", monitorName)

    Rectangle {
        anchors.fill: parent
        z: -1
        radius: Theme.radius
        color: root.open ? Theme.alpha(Theme.accentLight, 0.22) : Theme.clear
    }

    // A child of the button so it anchors under it
    ControlCenter {
        button: root
        open: root.open
    }
}
