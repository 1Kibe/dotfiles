import QtQuick
import Quickshell
import Quickshell.Networking
import qs.theme

// Cable, Wi-Fi by signal, or grey when offline. Click: nmtui.
// The network name only shows at runtime, in the tooltip.
BarItem {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property bool backend: devices.length > 0
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiNet: {
        for (const d of devices) {
            if (d.type !== DeviceType.Wifi)
                continue
            for (const n of d.networks.values) {
                if (n.connected)
                    return n
            }
        }
        return null
    }
    readonly property int strength: wifiNet ? Math.round(wifiNet.signalStrength * 100) : 0

    text: {
        if (wired)
            return "󰈀"
        if (wifiNet)
            return strength < 25 ? "󰤟" : strength < 50 ? "󰤢" : strength < 75 ? "󰤥" : "󰤨"
        if (!backend || !Networking.wifiEnabled)
            return "󰤮"
        return "󰤭"
    }
    textColor: wired || wifiNet ? Theme.text : Theme.gray
    tooltip: {
        if (wired)
            return "Cabo conectado"
        if (wifiNet)
            return `${wifiNet.name} — ${strength}%`
        if (!backend)
            return "NetworkManager não está rodando"
        if (!Networking.wifiEnabled)
            return "Wi-Fi desligado"
        return "Sem conexão"
    }
    onClicked: Quickshell.execDetached(["alacritty", "--class", "nmtui", "-e", "nmtui"])
}
