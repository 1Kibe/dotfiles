import QtQuick
import Quickshell.Bluetooth
import qs.theme
import qs.state

// Hidden without an adapter. Off, on, or connected devices. Click: the
// Bluetooth panel.
BarItem {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    readonly property string monitorName: monitor ? monitor.name : ""
    readonly property bool open: ShellState.isOpen("bluetooth", monitorName)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    readonly property var connected: powered ? adapter.devices.values.filter(d => d.connected) : []

    visible: adapter !== null
    text: !powered ? "󰂲" : connected.length === 0 ? "󰂯" : connected.length === 1 ? "󰂱" : `󰂱 ${connected.length}`
    textColor: powered ? Theme.text : Theme.gray
    tooltip: {
        if (open)
            return ""
        if (!powered)
            return "Bluetooth desligado"
        if (connected.length === 0)
            return "Nenhum aparelho conectado"
        return connected.map(d => d.batteryAvailable ? `${d.name} — ${Math.round(d.battery * 100)}%` : d.name).join("\n")
    }
    onClicked: ShellState.toggle("bluetooth", monitorName)

    BluetoothPanel {
        button: root
        open: root.open
    }
}
