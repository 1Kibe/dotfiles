import QtQuick
import qs.theme
import qs.state

// Power button at the end of the bar: drops the power menu down. Super+X
// and Ctrl+Alt+Del open the same menu (IpcHandler "powermenu" in shell.qml).
BarItem {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    readonly property string monitorName: monitor ? monitor.name : ""
    readonly property bool open: monitorName !== "" && ShellState.powerMenuOn === monitorName

    text: "󰐥"
    tooltip: open ? "" : "Energia"
    onClicked: ShellState.togglePowerMenu(monitorName)

    PowerMenu {
        button: root
        visible: root.open
    }
}
