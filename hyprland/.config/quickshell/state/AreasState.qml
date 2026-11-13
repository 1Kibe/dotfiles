pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../settings/monitors.js" as Monitors
import "../settings/hyprland.js" as Hypr

// Configurações → Monitores → Áreas de trabalho, outside Hyprland's config:
// each screen's position in the areas (k from 1 to 9: area N on it is
// workspace N*10+k, modules/areas.lua), kept in this machine's settings
// (monitorPositions, "port:k" pairs), and the windows of a screen that goes.
//
// A screen it has not seen takes the smallest position no screen has, saved
// or present (the same rule modules/areas.lua uses until this saves it), so
// the same screen comes back to the same part of every area. Saving waits a
// second for the screens to settle, writes only a change and at most a few
// times a minute.
//
// A screen that goes: its windows move to the first screen, in the same
// area, and are remembered (in memory only: port and description, the
// windows' addresses) so they go back when the very same screen comes back
// (same port and description; a different monitor on that port is a new
// screen). Addresses are checked (settings/hyprland.js) and must still be
// there; the move is a fixed Lua line with whole numbers. Nothing is
// focused, so it also runs with the session locked.
Singleton {
    id: root

    readonly property bool ready: SettingsStore.ready
    readonly property bool together: ready ? SettingsStore.get("areasTogether") !== false : true
    readonly property int maxAreas: 20

    // ── Positions ──
    // "port:k,…" → { port: k }, every pair checked again (no repeated port
    // or position, at most 9); anything off is left out
    function parse(text) {
        const out = {}
        const taken = {}
        if (typeof text !== "string" || text === "")
            return out
        const pairs = text.split(",")
        if (pairs.length > 9)
            return out
        for (const pair of pairs) {
            const m = /^(.+):([1-9])$/.exec(pair)
            if (!m || !Monitors.validName(m[1]) || out[m[1]] !== undefined || taken[m[2]])
                continue
            out[m[1]] = parseInt(m[2], 10)
            taken[m[2]] = true
        }
        return out
    }
    function format(map) {
        return Object.keys(map).sort((a, b) => map[a] - map[b]).map(n => `${n}:${map[n]}`).join(",")
    }
    // The rule shared with modules/areas.lua: saved ones keep theirs; a new
    // screen, in the order given, takes the smallest position no one has
    function place(saved, names) {
        const out = Object.assign({}, saved)
        const taken = {}
        for (const n of Object.keys(out))
            taken[out[n]] = true
        for (const n of names) {
            if (out[n] !== undefined || !Monitors.validName(n))
                continue
            for (let k = 1; k <= 9; k++) {
                if (!taken[k]) {
                    out[n] = k
                    taken[k] = true
                    break
                }
            }
        }
        return out
    }
    readonly property var saved: ready ? parse(String(SettingsStore.get("monitorPositions"))) : ({})

    // The screens that are on, from MonitorsApply (hyprctl, every name checked)
    readonly property var screensOn: MonitorsApply.screens.filter(s => s.enabled)
    onScreensOnChanged: settleTimer.restart()
    onReadyChanged: settleTimer.restart()

    Timer {
        id: settleTimer
        interval: 1000
        onTriggered: root.settle()
    }

    // A minute's worth of saves, at most
    property var saves: []
    readonly property int maxSavesPerMinute: 6
    property bool held: false

    function settle() {
        if (!ready)
            return
        const names = screensOn.map(s => s.name)
        const next = place(saved, names)
        const text = format(next)
        if (text !== String(SettingsStore.get("monitorPositions")) && text.length <= 400)
            save(text)
        follow(names)
    }

    // Make a screen the first one (its position becomes 1, the other's its
    // old one). Not while an arrangement is being tried or is waiting for
    // "Aplicar" (the reload would end it), nor with the session locked.
    // Clicks a second apart join into one save (one reload), within the
    // same few saves a minute as the rest.
    readonly property string firstBlocked: MonitorsApply.pending ? "Espere a prévia das telas acabar"
        : MonitorsApply.dirty ? "Aplique ou desfaça a mudança nas telas antes"
        : LockState.locked || LockState.wanted ? "Com a sessão travada, nada muda" : ""
    property string firstWanted: ""
    function makeFirst(name) {
        if (firstBlocked !== "" || !Monitors.validName(name))
            return false
        const map = place(saved, screensOn.map(s => s.name))
        if (map[name] === undefined || (map[name] === 1 && firstWanted === ""))
            return false
        firstWanted = name
        firstTimer.restart()
        return true
    }
    Timer {
        id: firstTimer
        interval: 1000
        onTriggered: {
            const name = root.firstWanted
            root.firstWanted = ""
            if (root.firstBlocked !== "" || !Monitors.validName(name))
                return
            const map = root.place(root.saved, root.screensOn.map(s => s.name))
            if (map[name] === undefined || map[name] === 1)
                return
            const first = Object.keys(map).find(n => map[n] === 1)
            if (first !== undefined)
                map[first] = map[name]
            map[name] = 1
            root.save(root.format(map))
        }
    }
    // A save within the minute's budget (shared by the screens' changes and
    // makeFirst)
    function save(text) {
        const now = Date.now()
        saves = saves.filter(t => now - t < 60000)
        if (saves.length >= maxSavesPerMinute) {
            if (!held)
                SettingsApply.failed("monitorPositions", "Telas mudando demais: as posições não foram salvas agora")
            held = true
            return false
        }
        held = false
        saves = saves.concat([now])
        SettingsStore.set("monitorPositions", text)
        return true
    }

    // ── Windows of a screen that goes ──
    // Screens seen with their description, and the windows that came from
    // each one that went: { "port|description": [{ address, area }] }
    property var known: ({})
    property var away: ({})
    readonly property int maxRemembered: 512

    function follow(names) {
        const positions = place(saved, names)
        const nowKnown = {}
        for (const s of screensOn)
            nowKnown[s.name] = s.description
        // Gone: their windows to the first screen
        for (const port of Object.keys(known)) {
            if (nowKnown[port] === undefined && positions[port] !== undefined)
                bringOver(port, known[port], positions[port], positions)
        }
        // Back, the very same screen: its windows home
        for (const port of Object.keys(nowKnown)) {
            const key = `${port}|${nowKnown[port]}`
            if (known[port] === undefined && away[key] !== undefined && positions[port] !== undefined)
                sendHome(key, positions[port])
        }
        known = nowKnown
    }
    function firstOf(positions) {
        let best = 0
        for (const n of Object.keys(positions))
            if (screensOn.some(s => s.name === n) && (best === 0 || positions[n] < best))
                best = positions[n]
        return best
    }
    function bringOver(port, description, k, positions) {
        if (!together)
            return
        const target = firstOf(positions)
        if (target === 0 || target === k)
            return
        clients(list => {
            const moved = []
            for (const c of list) {
                const id = c.workspace && c.workspace.id
                const address = Hypr.windowAddress(c.address)
                if (address === "" || !Number.isInteger(id) || id % 10 !== k || id < 11 || id > maxAreas * 10 + 9)
                    continue
                const area = Math.floor(id / 10)
                moveWindow(address, area * 10 + target)
                moved.push({ address: address, area: area })
            }
            if (moved.length === 0)
                return
            const next = Object.assign({}, away)
            const key = `${port}|${description}`
            next[key] = (next[key] || []).concat(moved)
            // At most 9 screens remembered and 512 windows in all
            const keys = Object.keys(next)
            while (keys.length > 9)
                delete next[keys.shift()]
            let total = 0
            for (const kk of Object.keys(next)) {
                next[kk] = next[kk].slice(0, Math.max(0, maxRemembered - total))
                total += next[kk].length
            }
            away = next
        })
    }
    function sendHome(key, k) {
        const list = away[key]
        const next = Object.assign({}, away)
        delete next[key]
        away = next
        clients(current => {
            const here = {}
            for (const c of current) {
                const a = Hypr.windowAddress(c.address)
                if (a !== "")
                    here[a] = true
            }
            for (const w of list) {
                if (here[w.address] && Number.isInteger(w.area) && w.area >= 1 && w.area <= maxAreas)
                    moveWindow(w.address, w.area * 10 + k)
            }
        })
    }
    // A closed window leaves the memory (a reused address must never move
    // someone else's window)
    function forget(address) {
        const a = Hypr.windowAddress(address)
        if (a === "")
            return
        const next = {}
        for (const key of Object.keys(away))
            next[key] = away[key].filter(w => w.address !== a)
        away = next
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "closewindow")
                root.forget(String(event.data))
        }
    }

    // ── Commands (fixed Lua, checked values only) ──
    function moveWindow(address, workspace) {
        if (Hypr.windowAddress(address) !== address || !Number.isInteger(workspace)
                || workspace < 11 || workspace > maxAreas * 10 + 9)
            return
        run(["hyprctl", "eval",
             `hl.dispatch(hl.dsp.window.move({ window = "address:${address}", workspace = ${workspace}, follow = false }))`])
    }
    function clients(done) {
        run(["hyprctl", "-j", "clients"], (code, out) => {
            let list = []
            try {
                list = JSON.parse(out)
            } catch (e) {
                list = []
            }
            done(Array.isArray(list) ? list : [])
        })
    }
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
