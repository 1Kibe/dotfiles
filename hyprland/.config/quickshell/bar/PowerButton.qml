import QtQuick
import qs.theme
import qs.state

// Power button at the end of the bar: drops the power menu down. Super+X
// and Ctrl+Alt+Del open the same menu (IpcHandler "powermenu" in shell.qml).
BarItem {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    readonly property string monitorName: monitor ? monitor.name : ""
    // ShellState is shared with the keybinds, so a menu opened by Super+X
    // shows here as open too
    readonly property bool open: ShellState.isOpen("power", monitorName)

    text: "󰐥"
    tooltip: open ? "" : "Energia"
    onClicked: ShellState.toggle("power", monitorName)

    // A child of the button so it anchors under it
    PowerMenu {
        button: root
        open: root.open
    }
}
