pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// The one owner of the Wi-Fi scan: it runs while the bar's network panel is
// open, or the control center with its Wi-Fi section folded out, on any
// monitor. One Binding for the whole shell: with a panel per bar, each
// binding the same property, a closed panel on one monitor would switch off
// the scan another monitor's open panel asked for.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wanted: ShellState.openPanel === "network"
                                   || (ShellState.openPanel === "control" && ShellState.controlSection === "wifi")

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.wanted
        when: root.wifiDevice !== null
    }
}
