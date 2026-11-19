pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../control/levels.js" as Levels

// The internal screen's brightness for the control center's slider, through
// brightnessctl (class backlight; logind writes it, no group needed). One
// instance for every monitor. It reads only while the control center is
// open: once when it opens and once after each write, never in a loop.
// Writes go one at a time, at least 80 ms apart, the last asked one winning
// (dragging never starts a process per pixel), on the keys' curve (-e4)
// with the keys' floor (-n2). The percent is checked again right before the
// command is put together: a whole number from 1 to 100, nothing else.
// Without a backlight (a desktop, the VM) `available` stays false and no
// write ever runs. The commands are fixed lists (through sh -c 'exec "$@"',
// so a missing brightnessctl does not put its arguments in the shell's log)
// and their output never reaches the screen or the log.
Singleton {
    id: root

    readonly property bool active: ShellState.openPanel === "control"
    property bool available: false
    // On the keys' curve, like the slider
    property int percent: 0

    property int pending: -1    // the last percent asked, not written yet
    property bool writing: false
    property double lastWrite: 0
    // Writes that ran (for the tests)
    property int writes: 0

    function refresh() {
        if (!active || reader.running)
            return
        readTimeout.restart()
        reader.running = true
    }

    // From the slider: false when refused (not available, not 1..100)
    function set(n) {
        if (!active || !available || !Levels.validPercent(n))
            return false
        pending = n
        percent = n
        flush()
        return true
    }

    function flush() {
        if (pending < 0 || writing)
            return
        const wait = 80 - (Date.now() - lastWrite)
        if (wait > 0) {
            gap.interval = Math.ceil(wait)
            gap.restart()
            return
        }
        const n = pending
        pending = -1
        // The argument below comes from here only: checked once more
        if (!active || !available || !Levels.validPercent(n))
            return
        writing = true
        lastWrite = Date.now()
        writes++
        writer.command = ["sh", "-c", 'exec brightnessctl "$@"', "sh", "-c", "backlight", "-e4", "-n2", "set", `${n}%`]
        writeTimeout.restart()
        writer.running = true
    }

    onActiveChanged: {
        if (active) {
            refresh()
        } else {
            reader.running = false
            gap.stop()
            pending = -1
        }
    }

    Process {
        id: reader
        command: ["sh", "-c", 'exec brightnessctl "$@"', "sh", "-c", "backlight", "-m"]
        stdout: StdioCollector { id: readOut }
        stderr: StdioCollector {}
        onExited: code => {
            readTimeout.stop()
            const m = code === 0 ? Levels.parseMachine(readOut.text) : null
            root.available = m !== null
            if (m !== null && !root.writing && root.pending < 0)
                root.percent = Levels.curvePercent(m.current, m.max)
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: {
            writeTimeout.stop()
            root.writing = false
            if (root.pending >= 0)
                root.flush()
            else
                root.refresh()
        }
    }
    Timer {
        id: gap
        onTriggered: root.flush()
    }
    // A command that hangs is stopped (SIGTERM) after 3 s
    Timer {
        id: readTimeout
        interval: 3000
        onTriggered: reader.running = false
    }
    Timer {
        id: writeTimeout
        interval: 3000
        onTriggered: writer.running = false
    }
}
