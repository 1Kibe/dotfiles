import QtQuick
import Quickshell.Services.UPower
import qs.theme

// Laptop battery: icon by 10%, percent, color by level. Hidden without one.
BarItem {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.ready && device.isLaptopBattery && device.isPresent
    readonly property int percent: present ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging
    readonly property bool full: present && (device.state === UPowerDeviceState.FullyCharged
                                             || device.state === UPowerDeviceState.PendingCharge)
    readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    function duration(seconds) {
        const minutes = Math.round(seconds / 60)
        const h = Math.floor(minutes / 60)
        const m = minutes % 60
        return h > 0 ? `${h}h ${m}min` : `${m}min`
    }

    visible: present
    clickable: false
    text: `${charging ? "󰂄" : icons[Math.min(9, Math.floor(percent / 10))]} ${percent}%`
    textColor: charging ? Theme.aqua : percent <= 15 ? Theme.red : percent <= 30 ? Theme.yellow : Theme.green
    tooltip: {
        if (!present)
            return ""
        if (full)
            return "Carregada"
        if (charging)
            return device.timeToFull > 0 ? `Cheia em ${duration(device.timeToFull)}` : "Calculando…"
        return device.timeToEmpty > 0 ? `${duration(device.timeToEmpty)} restantes` : "Calculando…"
    }
}
