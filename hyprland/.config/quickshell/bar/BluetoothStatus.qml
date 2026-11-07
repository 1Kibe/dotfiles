import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.theme

// Hidden without an adapter. Off, on, or connected devices. Click: bluetui.
BarItem {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    readonly property var connected: powered ? adapter.devices.values.filter(d => d.connected) : []

    visible: adapter !== null
    text: !powered ? "󰂲" : connected.length === 0 ? "󰂯" : connected.length === 1 ? "󰂱" : `󰂱 ${connected.length}`
    textColor: powered ? Theme.text : Theme.gray
    tooltip: {
        if (!powered)
            return "Bluetooth desligado"
        if (connected.length === 0)
            return "Nenhum aparelho conectado"
        return connected.map(d => d.batteryAvailable ? `${d.name} — ${Math.round(d.battery * 100)}%` : d.name).join("\n")
    }
    onClicked: Quickshell.execDetached(["alacritty", "--class", "bluetui", "-e", "bluetui"])
}
