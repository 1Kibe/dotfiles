pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.state
import "../control/lists.js" as Lists

// Tailscale for the control center: read only. "tailscale status --json"
// (as the user, no operator needed), its output read line by line up to
// 4 MiB and 5 s, kept only by the white list of lists.js tsParse (the
// state, and of this device and each peer the name, the tailnet addresses,
// online, the exit node fields and when last seen). The details live only
// while the section is open (read at the opening and every 10 s, one read
// at a time) and are dropped when it closes; the button keeps only the
// generic state, read once when the control center opens. Connecting and
// disconnecting open Kitty with the fixed script hypr-tailscale (sudo is
// typed there, never here); the shell never changes the tailnet itself
// (no operator, no "tailscale set"): the exit node is only shown. Copying
// this device's address goes to wl-copy --sensitive through its input
// only, never as an argument.
Singleton {
    id: root

    // "" not read yet, "off" no answer (no tailscaled, no program), else
    // one of lists.js TS_STATES or "unknown"
    property string backend: ""
    property bool exitActive: false
    property var self: null
    property var peers: []
    readonly property var exits: peers.filter(p => p.exitOption)
    readonly property var exitNode: peers.find(p => p.exitNode) ?? null
    readonly property string summary: Lists.tsSummary(backend, exitActive)
    readonly property bool locked: LockState.wanted || LockState.locked

    // How many lists show the details (the section, per monitor)
    property int watchers: 0
    function watch(on) {
        watchers = Math.max(0, watchers + (on ? 1 : -1))
        if (watchers > 0) {
            read(true)
        } else {
            self = null
            peers = []
        }
    }
    // The control center opened: the generic state only
    function readState() {
        read(watchers > 0)
    }

    property bool details: false
    property var chunks: []
    property int bytes: 0
    property bool overflow: false
    function read(withDetails) {
        if (reader.running)
            return
        details = withDetails === true
        chunks = []
        bytes = 0
        overflow = false
        readTimeout.restart()
        reader.running = true
    }
    Process {
        id: reader
        command: ["sh", "-c", 'exec "$@"', "sh", "tailscale", "status", "--json"]
        stdout: SplitParser {
            onRead: line => {
                if (root.overflow)
                    return
                root.bytes += line.length + 1
                if (root.bytes > Lists.TS_MAX_BYTES) {
                    root.overflow = true
                    root.chunks = []
                    reader.running = false
                    return
                }
                root.chunks.push(line)
            }
        }
        onExited: code => {
            readTimeout.stop()
            const text = root.chunks.join("\n")
            root.chunks = []
            const st = code === 0 && !root.overflow ? Lists.tsParse(text) : null
            if (st === null) {
                root.backend = "off"
                root.exitActive = false
                root.self = null
                root.peers = []
                return
            }
            root.backend = st.state
            root.exitActive = st.state === "Running" && st.peers.some(p => p.exitNode)
            if (root.details && root.watchers > 0) {
                root.self = st.self
                root.peers = st.peers
            }
        }
    }
    Timer {
        id: readTimeout
        interval: 5000
        onTriggered: {
            root.overflow = true
            reader.running = false
        }
    }
    // Every 10 s, only while a list shows the details
    Timer {
        interval: 10000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.read(true)
    }

    // Connect or disconnect: Kitty with the fixed script, in the control
    // center's special workspace; clicks within 3 s are ignored
    property double openedAt: 0
    function openTerminal(action) {
        if (locked || (action !== "up" && action !== "down") || Date.now() - openedAt < 3000)
            return false
        openedAt = Date.now()
        Quickshell.execDetached(["kitty", "--class", "qs-central", "hypr-tailscale", action])
        return true
    }

    // This device's address, as the last read gave it, to the clipboard:
    // only through wl-copy's input (one line read, then wl-copy gets it
    // and its end), marked sensitive so the clipboard history leaves it out
    function copy(ip) {
        if (locked || copier.running || !self || !self.ips.includes(ip) || !Lists.tsAddress(ip))
            return false
        copier.input = ip + "\n"
        copier.stdinEnabled = true
        copyTimeout.restart()
        copier.running = true
        return true
    }
    Process {
        id: copier
        property string input: ""
        command: ["sh", "-c", 'IFS= read -r a || exit 1; printf "%s" "$a" | exec wl-copy --sensitive', "sh"]
        onStarted: {
            write(input)
            input = ""
            stdinEnabled = false
        }
        onExited: {
            copyTimeout.stop()
            input = ""
        }
    }
    Timer {
        id: copyTimeout
        interval: 3000
        onTriggered: copier.running = false
    }
}
