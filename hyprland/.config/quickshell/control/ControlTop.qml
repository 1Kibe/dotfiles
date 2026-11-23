import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.theme
import qs.state
import qs.bar
import "../bar/battery.js" as Battery
import "power.js" as Power

// The top line of the control center: the battery on the left (icon and
// percent, and "Conservação ligada" while the charge limit is on; nothing
// without a battery), the gear (the settings, like Super+S) and the power
// icon (folds out the power section) on the right.
RowLayout {
    id: root

    required property string monitorName
    // The button the keyboard is on (0 the gear, 1 power; -1 none)
    property int keyIndex: -1

    // UPower's combined battery, as the bar's (BatteryStatus)
    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.ready && device.isLaptopBattery && device.isPresent
    readonly property int percent: present ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging
    readonly property bool known: present && Battery.known(device.percentage, device.energy, charging)

    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 4
    spacing: 6

    Text {
        visible: root.present
        text: root.known ? `${Battery.icon(root.percent, root.charging)} ${root.percent}%` : `${Battery.UNKNOWN} Carga desconhecida`
        textFormat: Text.PlainText
        color: Theme.text
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }
    Text {
        visible: root.present && EnergyApply.conservationAvailable && EnergyApply.conservation
        text: "Conservação ligada"
        textFormat: Text.PlainText
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }
    Item {
        Layout.fillWidth: true
    }
    BarItem {
        // nf-md-cog, as the panels' "Mais opções…"
        text: String.fromCodePoint(0xF0493)
        tooltip: "Configurações · Super+S"
        keyFocus: root.keyIndex === 0
        onClicked: ShellState.toggle("settings", root.monitorName)
    }
    BarItem {
        text: Power.ACTIONS.find(a => a.id === "poweroff").icon
        textColor: Theme.red
        tooltip: ShellState.controlSection === "power" ? "" : "Energia"
        keyFocus: root.keyIndex === 1
        onClicked: ShellState.setControlSection("power")
    }
}
