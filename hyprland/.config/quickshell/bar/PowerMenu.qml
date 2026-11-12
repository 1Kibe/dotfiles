import QtQuick
import Quickshell
import qs.theme
import qs.state
import "../settings/powermenu.js" as Menu

// Power menu that drops down from the power button (and Super+X): lock, log
// out, suspend, reboot, power off. Configurações → Energia picks which ones
// show and which also ask for a second click; reboot and power off always do.
AttachedPanel {
    id: root

    property string armed: ""   // action waiting for its second click
    property double armedAt: 0

    // The fixed table: the settings choose ids only, the commands are these.
    // Log out stops the uwsm session when Hyprland runs under it, else exits
    // Hyprland (dispatch takes Lua).
    readonly property var actions: [
        // Through hypr-travar, the single way to lock
        { id: "lock", icon: "󰌾", label: "Bloquear", command: ["hypr-travar"] },
        { id: "logout", icon: "󰍃", label: "Sair",
          command: ["sh", "-c", "uwsm check is-active && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"] },
        // Locks first and sleeps only once the lock is confirmed, even if
        // hypridle (which also locks before sleeping) is not running
        { id: "suspend", icon: "󰤄", label: "Suspender", command: ["sh", "-c", "hypr-travar && systemctl suspend"] },
        { id: "reboot", icon: "󰜉", label: "Reiniciar", command: ["systemctl", "reboot"] },
        { id: "poweroff", icon: "󰐥", label: "Desligar", command: ["systemctl", "poweroff"] }
    ]
    readonly property var shown: Menu.items(actions, SettingsStore.ready ? SettingsStore.get("powerMenuItems") : null)
    readonly property var confirmIds: SettingsStore.ready ? SettingsStore.get("powerConfirm") : []

    // First click on a confirm action only arms it; a click on another
    // confirm row moves the arm there. The second click on the armed row
    // runs, unless it comes right after the first (a double click).
    function run(action) {
        if (Menu.needsConfirm(action.id, confirmIds)) {
            if (armed !== action.id) {
                armed = action.id
                armedAt = Date.now()
                disarmTimer.restart()
                return
            }
            if (Date.now() - armedAt < 300)
                return
        }
        armed = ""
        // Close the menu, then run detached: the command is not tied to the
        // shell, which may go away with the session
        ShellState.close()
        Quickshell.execDetached(action.command)
    }

    panelWidth: 290
    // Continues the bar's right end (the only panel that does)
    side: "right"
    // A stale arm never turns one click into a reboot: opening or closing,
    // 5 s without the second click, or the menu's choices changing disarm it
    onOpenChanged: armed = ""
    onShownChanged: armed = ""
    onConfirmIdsChanged: armed = ""
    Timer {
        id: disarmTimer
        interval: 5000
        onTriggered: root.armed = ""
    }

    Repeater {
        model: root.shown

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
