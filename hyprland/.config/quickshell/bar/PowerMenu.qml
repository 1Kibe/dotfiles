import QtQuick
import Quickshell
import qs.theme
import qs.state

// Power menu that drops down from the power button: log out, suspend,
// reboot, power off. Reboot and power off need a second click.
DropPanel {
    id: root

    property string armed: ""   // action waiting for its second click

    readonly property var actions: [
        { id: "logout", icon: "󰍃", label: "Sair", confirm: false,
          command: ["sh", "-c", "uwsm check is-active && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"] },
        { id: "suspend", icon: "󰤄", label: "Suspender", confirm: false, command: ["systemctl", "suspend"] },
        { id: "reboot", icon: "󰜉", label: "Reiniciar", confirm: true, command: ["systemctl", "reboot"] },
        { id: "poweroff", icon: "󰐥", label: "Desligar", confirm: true, command: ["systemctl", "poweroff"] }
    ]

    function run(action) {
        if (action.confirm && armed !== action.id) {
            armed = action.id
            return
        }
        ShellState.close()
        Quickshell.execDetached(action.command)
    }

    panelWidth: 290
    onOpenChanged: armed = ""

    Repeater {
        model: root.actions

        PanelRow {
            required property var modelData

            icon: modelData.icon
            text: root.armed === modelData.id ? `Clique de novo para ${modelData.label.toLowerCase()}` : modelData.label
            danger: root.armed === modelData.id
            onClicked: root.run(modelData)
        }
    }
}
