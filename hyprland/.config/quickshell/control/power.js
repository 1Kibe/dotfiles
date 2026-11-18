.pragma library

// The power section of the control center (control/PowerList.qml): the one
// table of its actions, with fixed commands and no value from outside. The
// settings (Configurações → Energia) pick ids only, never a command. Lock
// only through hypr-travar; suspend and log out through their scripts
// (hypr-suspender locks first and sleeps only once the lock is confirmed).
// Plain JS: read by the shell and by the tests.
var ACTIONS = [
    { id: "lock", icon: "󰌾", label: "Bloquear", command: ["hypr-travar"] },
    { id: "logout", icon: "󰍃", label: "Sair", command: ["hypr-sair"] },
    { id: "suspend", icon: "󰤄", label: "Suspender", command: ["hypr-suspender"] },
    { id: "reboot", icon: "󰜉", label: "Reiniciar", command: ["systemctl", "reboot"] },
    { id: "poweroff", icon: "󰐥", label: "Desligar", command: ["systemctl", "poweroff"] }
]

// Reboot and power off always ask for the second click, whatever the
// settings say (they are not even among the choices)
var ALWAYS_CONFIRM = ["reboot", "poweroff"]

// table: the menu's actions ({ id, ... }); ids: powerMenuItems. The table's
// actions in the order of the ids, unknown ids and repeats left out; none
// left (an empty or broken list): the whole table, so the menu never ends
// up empty.
function items(table, ids) {
    const out = []
    if (Array.isArray(ids)) {
        for (const id of ids) {
            const a = table.find(t => t.id === id)
            if (a && !out.includes(a))
                out.push(a)
        }
    }
    return out.length > 0 ? out : table.slice()
}

// confirmIds: powerConfirm (lock, logout and suspend may be added to it)
function needsConfirm(id, confirmIds) {
    return ALWAYS_CONFIRM.includes(id) || (Array.isArray(confirmIds) && confirmIds.includes(id))
}
