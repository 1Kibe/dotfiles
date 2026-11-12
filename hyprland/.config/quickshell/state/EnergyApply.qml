pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../settings/idle.js" as Idle

// Configurações → Energia, outside the shell: the idle times of the power
// source in use as hypridle listeners (settings/idle.js), written to
// ~/.config/hypr/hypridle.gerado.conf and read by hypr-hypridle, which
// checks the file again and falls back to the repo's own times.
//
// hypridle does not read its config again by a signal: after a change it is
// restarted (systemctl --user restart, one command), and only if it is
// running: a machine where it is stopped on purpose is never started by
// this. 1.5 s later the service must be active; if not, the last good file
// comes back (none: the repo's times) and it is restarted again.
//
// The lid (lidAction): "lock-suspend" is logind's own handling (it locks
// first, hypridle's before_sleep_cmd). "lock" keeps logind from sleeping on
// the lid with an inhibitor, fixed arguments, no password (the active
// session may hold the lid). It never outlives the shell: each one lasts
// 120 s (timeout) and a new one comes every 60 s, before the old one ends;
// if the shell stops, the last one runs out and the lid sleeps again, the
// safe side. The lid bind in keybinds.lua locks either way.
Singleton {
    id: root

    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr`
    readonly property string idleFile: `${hyprDir}/hypridle.gerado.conf`

    // ── The power source ──
    // No battery (a desktop, a VM): on power. UPower not answering: the set
    // of times that locks first
    readonly property var device: UPower.displayDevice
    readonly property bool known: device !== null && device.ready
    readonly property string source: !known ? "" : !device.isLaptopBattery ? "ac" : UPower.onBattery ? "bat" : "ac"
    // The source the file was written for; a change waits a moment (a
    // charger plugged in and out) before it counts
    property string usedSource: ""
    onSourceChanged: sourceTimer.restart()
    Timer {
        id: sourceTimer
        interval: 4000
        onTriggered: root.applyIdle()
    }

    function times(set) {
        const sfx = set === "bat" ? "Bat" : "Ac"
        return {
            warn: SettingsStore.get("idleWarn" + sfx), lock: SettingsStore.get("idleLock" + sfx),
            screenOff: SettingsStore.get("idleScreenOff" + sfx), suspend: SettingsStore.get("idleSuspend" + sfx)
        }
    }
    // Unknown source: the set whose lock comes first ("Nunca" is last)
    function pickSet() {
        if (source !== "")
            return source
        const ac = times("ac").lock, bat = times("bat").lock
        const a = ac > 0 ? ac : Infinity, b = bat > 0 ? bat : Infinity
        return a < b ? "ac" : "bat"
    }

    // ── The file ──
    property string wanted: ""
    property string written: ""
    property string lastGood: ""
    property bool loaded: false
    // The page's key to give back when the times cannot be used
    property string failKey: "idleLockAc"

    function applyIdle() {
        if (!SettingsStore.ready)
            return
        const set = pickSet()
        const r = Idle.listeners(times(set), set)
        if (!r.ok) {
            SettingsApply.failed(failKey, r.error)
            return
        }
        usedSource = set
        wanted = r.text
        write()
    }
    function write() {
        if (!loaded || wanted === "" || wanted === written)
            return
        idleView.setText(wanted)
    }
    FileView {
        id: idleView
        path: root.idleFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            root.written = text()
            root.lastGood = root.written
            root.loaded = true
            root.write()
        }
        onLoadFailed: {
            root.loaded = true
            root.write()
        }
        onSaved: {
            root.written = root.wanted
            root.restartIfRunning()
        }
        onSaveFailed: SettingsApply.failed(root.failKey, "Não deu para salvar os tempos")
    }

    // ── Restarting hypridle ──
    // At most one restart every 30 s: a later change waits for the rest
    property double lastRestart: 0
    property bool rollingBack: false
    function restartIfRunning() {
        run(["systemctl", "--user", "is-active", "--quiet", "hypridle"], code => {
            if (code !== 0) {
                // Stopped on purpose (or not this session): the file is
                // read at its next start
                if (!root.rollingBack)
                    root.lastGood = root.written
                return
            }
            const wait = 30000 - (Date.now() - root.lastRestart)
            if (wait > 0) {
                restartTimer.interval = wait
                restartTimer.restart()
            } else {
                root.restart()
            }
        })
    }
    Timer {
        id: restartTimer
        onTriggered: root.restart()
    }
    function restart() {
        lastRestart = Date.now()
        run(["systemctl", "--user", "restart", "hypridle"], () => checkTimer.restart())
    }
    Timer {
        id: checkTimer
        interval: 1500
        onTriggered: root.check()
    }
    function check() {
        run(["systemctl", "--user", "show", "-p", "ActiveState", "-p", "MainPID", "--value", "hypridle"], (code, out) => {
            const [state, pid] = out.trim().split("\n")
            if (state === "active" && parseInt(pid) > 0) {
                root.lastGood = root.written
                root.rollingBack = false
                return
            }
            if (root.rollingBack)
                return
            // Back to the last good file, or to the repo's times
            root.rollingBack = true
            SettingsApply.failed(root.failKey, "O hypridle não aceitou os tempos")
            if (root.lastGood !== "" && root.lastGood !== root.written) {
                root.wanted = root.lastGood
                idleView.setText(root.lastGood)
            } else {
                run(["rm", "-f", "--", root.idleFile], () => {
                    root.written = ""
                    root.wanted = ""
                    root.lastRestart = 0
                    root.restart()
                })
            }
        })
    }

    // ── The lid ──
    readonly property var inhibitCommand: [
        "timeout", "120", "systemd-inhibit", "--what=handle-lid-switch", "--mode=block", "--who=Quickshell",
        "--why=Só travar ao fechar a tampa", "--", "sleep", "infinity"
    ]
    // The inhibitor is confirmed up (the page shows the choice only then)
    property bool lidHeld: false
    // The choice before "lock", given back when the lid cannot be held at
    // all; a renewal that fails later (the session not the active one for a
    // moment) only tries again at the next one
    property string lidBefore: "lock-suspend"
    property bool firstHold: false
    property var holders: []
    function applyLid() {
        if (!SettingsStore.ready)
            return
        if (SettingsStore.get("lidAction") === "lock") {
            if (!renewTimer.running) {
                firstHold = true
                holdLid()
                renewTimer.start()
            }
        } else {
            renewTimer.stop()
            releaseLid()
            lidBefore = SettingsStore.get("lidAction")
        }
    }
    Timer {
        id: renewTimer
        interval: 60000
        repeat: true
        onTriggered: root.holdLid()
    }
    function holdLid() {
        const p = holderComponent.createObject(root, { command: inhibitCommand })
        holders = holders.concat([p])
        p.running = true
        confirmTimer.restart()
    }
    function releaseLid() {
        for (const p of holders)
            p.running = false
        holders = []
        lidHeld = false
    }
    Component {
        id: holderComponent
        Process {
            id: holder
            onRunningChanged: {
                if (!running) {
                    root.holders = root.holders.filter(p => p !== holder)
                    holder.destroy()
                }
            }
        }
    }
    Timer {
        id: confirmTimer
        interval: 1500
        onTriggered: root.confirmLid()
    }
    function confirmLid() {
        run(["systemd-inhibit", "--list", "--no-pager", "--no-legend", "--mode=block"], (code, out) => {
            if (SettingsStore.get("lidAction") !== "lock")
                return
            const held = out.split("\n").some(l => l.startsWith("Quickshell ") && l.includes(" handle-lid-switch "))
            if (held) {
                root.lidHeld = true
                root.firstHold = false
                return
            }
            root.lidHeld = false
            if (!root.firstHold)
                return
            // Never held: back to the choice before, with the failure
            renewTimer.stop()
            root.releaseLid()
            SettingsApply.failed("lidAction", "Não deu para segurar a tampa")
            SettingsStore.set("lidAction", root.lidBefore)
        })
    }

    Connections {
        target: SettingsStore
        function onReadyChanged() {
            root.applyIdle()
            root.applyLid()
        }
        function onChanged(key) {
            if (key.startsWith("idle")) {
                root.failKey = key
                root.rollingBack = false
                root.applyIdle()
            } else if (key === "lidAction") {
                root.applyLid()
            }
        }
    }
    Component.onCompleted: {
        applyIdle()
        applyLid()
    }

    // ── Commands (argument lists only) ──
    component Job: Process {
        property var done: null
        property bool finished: false
        stdout: StdioCollector {
            id: out
        }
        function finish(code, text) {
            if (finished)
                return
            finished = true
            if (done)
                done(code, text)
            destroy()
        }
        onExited: code => finish(code, out.text)
        onRunningChanged: {
            if (!running && !finished)
                Qt.callLater(() => finish(-1, ""))
        }
    }
    Component {
        id: jobComponent
        Job {}
    }
    function run(command, done) {
        const job = jobComponent.createObject(root, { command: command, done: done || null })
        job.running = true
    }
}
