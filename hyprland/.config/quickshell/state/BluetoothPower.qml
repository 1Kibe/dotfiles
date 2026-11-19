pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// The Bluetooth switch, the same for the control center and the bar's
// panel. Off blocks the radio with rfkill and on unblocks it, then powers
// the adapter once BlueZ no longer sees it blocked (up to 3 s): a block
// lasts through a reboot (systemd-rfkill keeps it), where turning only the
// adapter off would not. The commands are fixed; /dev/rfkill is writable by
// the session's user. One change at a time, 5 s at most; a failure shows a
// fixed message and the switch follows the adapter as it is.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool powered: available && adapter.enabled
    readonly property bool blocked: available && adapter.state === BluetoothAdapterState.Blocked
    property bool busy: false
    property string error: ""
    property bool wantOn: false
    property int waitTries: 0

    function toggle() {
        set(!powered)
    }
    function set(on) {
        if (!available || busy)
            return
        error = ""
        wantOn = on === true
        busy = true
        job.command = ["sh", "-c", 'exec "$@"', "sh", "rfkill", wantOn ? "unblock" : "block", "bluetooth"]
        deadline.restart()
        job.running = true
    }
    function clearError() {
        error = ""
    }
    function fail() {
        deadline.stop()
        powerWait.stop()
        busy = false
        error = "Não deu para mudar o Bluetooth"
    }

    // No reader on its output: nothing of it is kept or logged
    Process {
        id: job
        onExited: code => {
            deadline.stop()
            if (code !== 0) {
                root.fail()
            } else if (root.wantOn) {
                root.waitTries = 0
                powerWait.restart()
            } else {
                root.busy = false
            }
        }
    }
    Timer {
        id: deadline
        interval: 5000
        onTriggered: {
            job.running = false
            root.fail()
        }
    }
    // After the unblock: power on as soon as BlueZ lets it, every 0.25 s
    Timer {
        id: powerWait
        interval: 250
        repeat: true
        onTriggered: {
            if (!root.available) {
                root.fail()
            } else if (!root.blocked) {
                stop()
                if (!root.adapter.enabled)
                    root.adapter.enabled = true
                root.busy = false
            } else if (++root.waitTries >= 12) {
                root.fail()
            }
        }
    }
}
