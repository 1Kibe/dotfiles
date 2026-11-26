pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

// A change of profile or theme from a frozen frame of the screen
// (wallpaper/SwapFrames): each monitor's picture is frozen in memory and
// covers it (an overlay that takes no input), the change happens underneath
// (colors, files, the wallpaper at once), and once the new wallpaper is on
// screen (1.5 s at most) the frozen frame leaves with the transition chosen
// in Configurações → Perfis (circle, fade, slide or curtain), and is dropped.
// One change at a time: one asked meanwhile waits, and only the last one
// asked counts. Nothing runs with the screen locked (or while the monitors or
// the keyboard layout are being applied); the lock coming in drops the frame
// at once, ends the change without animation and drops the one waiting.
// A monitor added or removed meanwhile drops every frame before anything
// else (a capture of a monitor that leaves loses both frames). With no frame
// (no overlay, or the capture did not come in time) the change happens
// directly, with the wallpaper's own fade; reduce motion: the fade; speed 0:
// at once. A hard limit of 3 s ends any change. Never a file, a log, IPC or
// a command for the frames: only the cursor's position is read (hyprctl
// cursorpos, as two numbers) when the circle starts from it.
Singleton {
    id: root

    // "" | "freeze" (the frames being taken) | "cover" (the frames over the
    // screens, the change underneath) | "reveal" (the frames leaving)
    property string phase: ""
    readonly property bool active: phase !== ""
    // The wallpaper changes at once while a frame covers it
    readonly property bool covering: phase === "cover" || phase === "reveal"
    // The effect of this change, and where the circle starts (the monitor's
    // name and a point in it; elsewhere: the middle)
    property string kind: "circle"
    property string originScreen: ""
    property real originX: -1
    property real originY: -1

    // (read from LockState itself: called from its own change signals, a
    // binding of this object could still hold the old value)
    function isLocked() {
        return LockState.locked || LockState.wanted
    }
    function blocked() {
        return isLocked() || LockState.dimmed || MonitorsApply.pending || MonitorsApply.identifying || KeyboardLayout.pending
    }
    // Why the last change was refused, for the page that asked (the lock and
    // its veil: nothing to say); gone after a few seconds
    property string refusal: ""
    function refuse() {
        if (isLocked() || LockState.dimmed)
            return
        refusal = "Espere: os monitores ou o teclado estão sendo aplicados."
        refusalClear.restart()
    }
    Timer {
        id: refusalClear
        interval: 5000
        onTriggered: root.refusal = ""
    }
    // A change going on, being prepared or waiting
    readonly property bool busy: active || current !== null || waiting !== null
    // Every change that ends (done, dropped or refused later)
    signal ended()
    function safely(change) {
        try {
            change()
        } catch (e) {
            console.warn(`SwapState: ${e}`)
        }
    }
    function effectKind() {
        if (Theme.reduceMotion)
            return "fade"
        const k = SettingsStore.values.profileSwap
        return ["circle", "fade", "slide", "curtain"].includes(k) ? k : "circle"
    }

    // ── Who takes part ──
    // The overlays that can freeze a monitor (by its name) and the
    // wallpapers to wait for
    property var frames: ({})
    property var wallpapers: []
    function addFrame(name, item) {
        const m = Object.assign({}, frames)
        m[name] = item
        frames = m
    }
    function removeFrame(name, item) {
        if (frames[name] !== item)
            return
        const m = Object.assign({}, frames)
        delete m[name]
        frames = m
    }
    function addWallpaper(w) {
        wallpapers = wallpapers.concat([w])
    }
    function removeWallpaper(w) {
        wallpapers = wallpapers.filter(x => x !== w)
    }
    function wallpapersSettled() {
        return wallpapers.every(w => w.settled)
    }
    // The frames say when they are in and when they have left
    property var ready: ({})
    property var revealed: ({})
    function frameReady(name) {
        if (phase !== "freeze" || ready[name])
            return
        const m = Object.assign({}, ready)
        m[name] = true
        ready = m
        if (Object.keys(frames).every(n => ready[n]))
            cover()
    }
    function frameRevealed(name) {
        if (phase !== "reveal" || revealed[name])
            return
        const m = Object.assign({}, revealed)
        m[name] = true
        revealed = m
        if (Object.keys(ready).every(n => revealed[n]))
            finish()
    }

    // ── Asking ──
    // change: a function doing the change (it checks again whatever it
    // needs; it runs later when another change is going on). opts.fromCursor:
    // the circle starts from the cursor (a click), else from the middle.
    // false: refused (locked); true: done, going on or waiting
    property var current: null
    property var waiting: null
    function run(change, opts) {
        if (typeof change !== "function")
            return false
        if (blocked()) {
            refuse()
            return false
        }
        if (active || current !== null) {
            waiting = { change: change, opts: opts || {} }
            return true
        }
        start(change, opts || {})
        return true
    }
    function start(change, opts) {
        // Nothing to freeze, no motion, or a minimized window flying: at once
        if (Theme.dur(1000) === 0 || Object.keys(frames).length === 0 || MinimizeState.flights.length > 0) {
            safely(change)
            ended()
            return
        }
        current = change
        kind = effectKind()
        const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        originScreen = focused
        originX = -1
        originY = -1
        ready = {}
        revealed = {}
        limit.restart()
        if (kind === "circle" && opts.fromCursor === true && focused !== "") {
            cursor.command = ["hyprctl", "cursorpos"]
            cursor.running = true
            return
        }
        freeze()
    }
    // The cursor, as two numbers inside the focused monitor
    Process {
        id: cursor
        stdout: StdioCollector {
            id: cursorOut
        }
        onExited: code => {
            const m = /^\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*$/.exec(cursorOut.text)
            const s = Quickshell.screens.find(x => x.name === root.originScreen)
            if (code === 0 && m && s) {
                const x = Number(m[1]) - s.x, y = Number(m[2]) - s.y
                if (x >= 0 && y >= 0 && x < s.width && y < s.height) {
                    root.originX = x
                    root.originY = y
                }
            }
            if (root.phase === "" && root.current !== null)
                root.freeze()
        }
    }
    function freeze() {
        if (current === null || blocked()) {
            drop(false)
            return
        }
        phase = "freeze"
        noFrame.restart()
    }
    // No frame in time (the capture failed): the change happens directly
    Timer {
        id: noFrame
        interval: 500
        onTriggered: {
            if (root.phase !== "freeze")
                return
            if (Object.keys(root.ready).length > 0)
                root.cover()
            else
                root.drop(true)
        }
    }
    function cover() {
        noFrame.stop()
        if (isLocked()) {
            drop(false)
            return
        }
        phase = "cover"
        const change = current
        current = null
        safely(change)
        settle.waited = 0
        settle.restart()
    }
    // The new wallpaper on screen (checked every 50 ms, 1.5 s at most; at
    // least two frames so the new colors are drawn under the frame)
    Timer {
        id: settle
        property int waited: 0
        interval: 50
        repeat: true
        onTriggered: {
            waited += interval
            if (waited >= 100 && (root.wallpapersSettled() || waited >= 1500)) {
                stop()
                root.phase = "reveal"
            }
        }
    }
    function finish() {
        limit.stop()
        settle.stop()
        noFrame.stop()
        phase = ""
        ready = {}
        revealed = {}
        runNext()
    }
    // The change waiting runs now; with none (or it refused), every change
    // has ended
    function runNext() {
        const next = waiting
        waiting = null
        if (next !== null && !blocked())
            Qt.callLater(() => {
                if (!root.run(next.change, next.opts))
                    root.ended()
            })
        else
            ended()
    }
    // Everything stops at once: the frames are dropped first; the change not
    // made yet happens directly (doIt) or not at all
    function drop(doIt) {
        const change = current
        current = null
        cursor.running = false
        limit.stop()
        settle.stop()
        noFrame.stop()
        phase = ""
        ready = {}
        revealed = {}
        const next = waiting
        waiting = null
        if (doIt && change !== null && !blocked())
            safely(change)
        waiting = next
        runNext()
    }
    // The hard limit: whatever happens, the frames go
    Timer {
        id: limit
        interval: 3000
        onTriggered: root.drop(true)
    }
    // The lock: the frames go now, the change waiting goes too
    function onLock() {
        if (!isLocked())
            return
        waiting = null
        if (active || current !== null)
            drop(false)
    }
    Connections {
        target: LockState
        function onLockedChanged() {
            root.onLock()
        }
        function onWantedChanged() {
            root.onLock()
        }
    }
    // A monitor added or removed: the frames go before anything else
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.active || root.current !== null)
                root.drop(true)
        }
    }
    onActiveChanged: ShellState.setOverlay("swap", active)
}
