import QtQuick
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.theme

// Top-right pill of the lock and login screens: keyboard layout, network
// and battery (the battery hides without one). Shared with the login screen:
// the layout comes from the caller; network and battery come from the
// system bus (NetworkManager, UPower), not from the session.
Rectangle {
    id: root

    property string layout: ""

    readonly property var devices: Networking.devices.values
    readonly property bool wired: devices.some(d => d.type === DeviceType.Wired && d.connected)
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

    // Same rules as bar/BatteryStatus: a VM or a desktop shows no battery
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property int percent: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property var batteryIcons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 32
    radius: height / 2
    color: Theme.lockPillFill

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        Text {
            visible: root.layout !== ""
            text: `󰌌 ${root.layout}`
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
        }

        Text {
            // Cable, Wi-Fi in four signal steps, or offline (grey)
            text: root.wired ? "󰈀"
                : root.wifiNet ? (root.strength < 25 ? "󰤟" : root.strength < 50 ? "󰤢" : root.strength < 75 ? "󰤥" : "󰤨")
                : "󰤭"
            color: root.wired || root.wifiNet ? Theme.text : Theme.gray
            font.family: Theme.font
            font.pixelSize: 15
        }

        Text {
            visible: root.hasBattery
            text: `${root.charging ? "󰂄" : root.batteryIcons[Math.min(9, Math.floor(root.percent / 10))]} ${root.percent}%`
            color: root.charging ? Theme.aqua : root.percent <= 15 ? Theme.red : root.percent <= 30 ? Theme.yellow : Theme.text
            font.family: Theme.font
            font.pixelSize: 14
        }
    }
}
