pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Configurações → Monitores → Luz noturna: hyprsunset at the chosen
// temperature between the chosen hours (nightLight, nightTemp, nightStart,
// nightEnd), with or without the panel open.
//
// hyprsunset runs as this shell's own child process, fixed arguments
// (["hyprsunset", "-t", <temperature>]), the temperature checked again here
// (a whole number from 2500 to 6500); turning it off ends that process (its
// own pid, never anything found by name). A new temperature while on: the
// old one ends, then the new one starts, never two at once. When the shell
// reloads, the process goes with the old shell and the new one starts its
// own. No config file is written.
//
// The hours come from a Quickshell Timer set to the next change; a second
// Timer notices a jump of the clock (a suspend, the time changed) and works
// it out again. An end before the start crosses midnight. If hyprsunset
// stops by itself it is started once more; a second stop gives up and says
// so (SettingsApply.failed). It is only color: it goes on with the session
// locked like any other time.
Singleton {
    id: root

    readonly property bool ready: SettingsStore.ready
    readonly property bool enabled: ready && SettingsStore.get("nightLight") === true
    // 0: not a temperature it takes
    readonly property int temperature: {
        const t = ready ? SettingsStore.get("nightTemp") : 0
        return typeof t === "number" && Number.isInteger(t) && t >= 2500 && t <= 6500 ? t : 0
    }
    readonly property string start: ready ? String(SettingsStore.get("nightStart")) : ""
    readonly property string end: ready ? String(SettingsStore.get("nightEnd")) : ""

    // Now between the hours
    property bool inside: false
    readonly property bool wanted: enabled && temperature > 0 && inside

    // ── The hours ──
    function minutes(hm) {
        const m = /^([01][0-9]|2[0-3]):([0-5][0-9])$/.exec(hm)
        return m ? parseInt(m[1], 10) * 60 + parseInt(m[2], 10) : -1
    }
    function check() {
        const s = minutes(start)
        const e = minutes(end)
        const now = new Date()
        if (s < 0 || e < 0 || s === e) {
            inside = false
            nextChange.interval = 60000
            nextChange.restart()
            return
        }
        const n = now.getHours() * 60 + now.getMinutes()
        inside = s < e ? n >= s && n < e : n >= s || n < e
        const next = inside ? e : s
        let left = (next - n + 1440) % 1440
        if (left === 0)
            left = 1440
        nextChange.interval = Math.max(1000, left * 60000 - now.getSeconds() * 1000 - now.getMilliseconds())
        nextChange.restart()
    }
    Timer {
        id: nextChange
        onTriggered: root.check()
    }
    // The clock jumped (suspend, a new time): work the hours out again
    Timer {
        id: clockWatch
        interval: 30000
        repeat: true
        running: true
        property double last: Date.now()
        onTriggered: {
            const now = Date.now()
            if (Math.abs(now - last - interval) > 5000)
                root.check()
            last = now
        }
    }
    onStartChanged: check()
    onEndChanged: check()
    onReadyChanged: check()
    Component.onCompleted: check()

    // ── hyprsunset ──
    property int runningAt: 0
    property bool stopping: false
    property bool restartAfterStop: false
    property int stops: 0

    onWantedChanged: {
        stops = 0
        apply()
    }
    onTemperatureChanged: apply()

    function apply() {
        if (!wanted) {
            if (sunset.running) {
                stopping = true
                sunset.running = false
            }
            return
        }
        if (sunset.running) {
            if (runningAt === temperature)
                return
            // The old one ends first; the new one starts when it is gone
            restartAfterStop = true
            stopping = true
            sunset.running = false
            return
        }
        startNow()
    }
    function startNow() {
        if (!wanted || temperature < 2500 || temperature > 6500)
            return
        runningAt = temperature
        sunset.command = ["hyprsunset", "-t", String(temperature)]
        sunset.running = true
    }
    Process {
        id: sunset
        onExited: {
            if (root.stopping) {
                root.stopping = false
                if (root.restartAfterStop) {
                    root.restartAfterStop = false
                    root.startNow()
                }
                return
            }
            // Stopped by itself: once more, then give up
            if (!root.wanted)
                return
            root.stops++
            if (root.stops <= 1)
                retry.restart()
            else
                SettingsApply.failed("nightLight", "A luz noturna parou e não voltou")
        }
    }
    Timer {
        id: retry
        interval: 2000
        onTriggered: root.startNow()
    }
}
