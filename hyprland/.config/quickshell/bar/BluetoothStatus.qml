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
    // Panels are per monitor: ShellState says whether ours is open on this bar
    readonly property bool open: ShellState.isOpen("bluetooth", monitorName)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    // Empty while off, so the icon shows "off" and never a stale count
    readonly property var connected: powered ? adapter.devices.values.filter(d => d.connected) : []

    visible: adapter !== null
    // Off, on with nothing connected, one device, or the icon with a count
    text: !powered ? "󰂲" : connected.length === 0 ? "󰂯" : connected.length === 1 ? "󰂱" : `󰂱 ${connected.length}`
    textColor: powered ? Theme.text : Theme.gray
    tooltip: {
        if (open)
            return ""
        if (!powered)
            return "Bluetooth desligado"
        if (connected.length === 0)
            return "Nenhum aparelho conectado"
        // One line per connected device, with its battery when it reports one
        return connected.map(d => d.batteryAvailable ? `${d.name} — ${Math.round(d.battery * 100)}%` : d.name).join("\n")
    }
    onClicked: ShellState.toggle("bluetooth", monitorName)

    // A child of the button so it anchors under it; ShellState opens it
    BluetoothPanel {
        button: root
        open: root.open
    }
}
