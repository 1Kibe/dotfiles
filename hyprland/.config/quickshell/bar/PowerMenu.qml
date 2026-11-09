import QtQuick
import Quickshell
import qs.theme
import qs.state

// Power menu that drops down from the power button (and Super+X): lock, log
// out, suspend, reboot, power off. Reboot and power off need a second click.
DropPanel {
    id: root

    property string armed: ""   // action waiting for its second click

    // confirm: needs the second click. Log out stops the uwsm session when
    // Hyprland runs under it, else exits Hyprland (dispatch takes Lua).
    readonly property var actions: [
        // Through hypr-travar, the single way to lock; nothing is lost, so
        // one click is enough
        { id: "lock", icon: "󰌾", label: "Bloquear", confirm: false, command: ["hypr-travar"] },
        { id: "logout", icon: "󰍃", label: "Sair", confirm: false,
          command: ["sh", "-c", "uwsm check is-active && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"] },
        // Locks first and sleeps only once the lock is confirmed, even if
        // hypridle (which also locks before sleeping) is not running
        { id: "suspend", icon: "󰤄", label: "Suspender", confirm: false,
          command: ["sh", "-c", "hypr-travar && systemctl suspend"] },
        { id: "reboot", icon: "󰜉", label: "Reiniciar", confirm: true, command: ["systemctl", "reboot"] },
        { id: "poweroff", icon: "󰐥", label: "Desligar", confirm: true, command: ["systemctl", "poweroff"] }
    ]

    // First click on a confirm action only arms it; a click on another
    // confirm row moves the arm there. The second click on the armed row runs.
    function run(action) {
        if (action.confirm && armed !== action.id) {
            armed = action.id
            return
        }
        // Close the menu, then run detached: the command is not tied to the
        // shell, which may go away with the session
        ShellState.close()
        Quickshell.execDetached(action.command)
    }

    panelWidth: 290
    // Opening or closing disarms, so a stale arm never turns one click into a reboot
    onOpenChanged: armed = ""

    Repeater {
        model: root.actions

        PanelRow {
            required property var modelData

            icon: modelData.icon
            text: root.armed === modelData.id ? `Clique de novo para ${modelData.label.toLowerCase()}` : modelData.label
            // The armed row turns red and asks for the second click
            danger: root.armed === modelData.id
            onClicked: root.run(modelData)
        }
    }
}
