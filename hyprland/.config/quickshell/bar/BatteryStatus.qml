import QtQuick
import Quickshell.Services.UPower
import qs.theme
import "battery.js" as Battery

// Laptop battery: icon by 10%, percent, color by level. Hidden without one.
BarItem {
    id: root

    // UPower's combined battery; on a desktop or a VM it is not a laptop
    // battery, so `present` stays false and the item hides
    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.ready && device.isLaptopBattery && device.isPresent
    readonly property int percent: present ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging
    // PendingCharge: plugged in but not charging (e.g. a charge limit); shown
    // as charged too
    readonly property bool full: present && (device.state === UPowerDeviceState.FullyCharged
                                             || device.state === UPowerDeviceState.PendingCharge)
    // No charge reported at all: an unknown battery, not an empty red one
    readonly property bool known: present && Battery.known(device.percentage, device.energy, charging)

    visible: present
    clickable: false
    text: known ? `${Battery.icon(percent, charging)} ${percent}%` : Battery.UNKNOWN
    textColor: !known ? Theme.gray : charging ? Theme.aqua : percent <= 15 ? Theme.red : percent <= 30 ? Theme.yellow : Theme.green
    tooltip: {
        if (!present)
            return ""
        if (!known)
            return "Carga desconhecida"
        if (full)
            return "Carregada"
        // UPower reports 0 while it is still estimating the time
        if (charging)
            return device.timeToFull > 0 ? `Cheia em ${Battery.duration(device.timeToFull)}` : "Calculando…"
        return device.timeToEmpty > 0 ? `${Battery.duration(device.timeToEmpty)} restantes` : "Calculando…"
    }
}
