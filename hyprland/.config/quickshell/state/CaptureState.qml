pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen capture (Print): the saved choices, the overlay session, the
// recording and the small notices. The UI is in capture/.
//
// Session phases: "choose" (the bar over the live screen, when there is a
// delay), "countdown", "select" (screen frozen, pick the area). Screen
// content and file paths never go to the log.
Singleton {
    id: root

    // ── Saved choices (~/.local/state/quickshell/capture.json) ──
    property string mode: "area"          // "area" | "window" | "screen"
    property string kind: "photo"         // "photo" | "video"
    property int delay: 0                 // 0 | 3 | 5 | 10 s
    property bool audioSystem: true
    property bool audioMic: false         // off unless chosen
    property string color: "red"          // Theme color name
    property int width: 3                 // 2 | 3 | 5 | 8

    // ── Session ──
    property bool open: false
    property string purpose: "capture"    // "capture" | "ocr" | "edit"
    property string editFile: ""
    property string phase: "idle"
    property string focusName: ""         // monitor with the bar, countdown and notices
    property string selOwner: ""          // monitor holding the selection
    property var monitors: ({})           // name -> { id, x, y, w, h (logical), scale, ws }
    property var windows: []              // visible windows, topmost first: { x, y, w, h (global logical), monitor, floating }
    property int countdownLeft: 0

    signal exportRequested(bool copy)     // Enter / Ctrl+C / Ctrl+S: the monitor holding the selection exports it

    // ── Annotation (this opening only) ──
    property string tool: "arrow"         // see capture/tools.js
    property bool blurMode: false         // the mosaic tool blurs instead
    // { id, tool, color, size, points: [{x, y}], fill, text, lineHeight, blur }
    // in the coordinates of the monitor holding the selection
    property var strokes: []
    property var redoStack: []
    property int nextId: 1

    function pushStroke(stroke) {
        strokes = strokes.concat([Object.assign({ id: nextId++ }, stroke)])
        redoStack = []
    }

    function undo() {
        if (strokes.length === 0)
            return
        redoStack = redoStack.concat([strokes[strokes.length - 1]])
        strokes = strokes.slice(0, -1)
    }

    function redo() {
        if (redoStack.length === 0)
            return
        strokes = strokes.concat([redoStack[redoStack.length - 1]])
        redoStack = redoStack.slice(0, -1)
    }

    // Choosing the mosaic again switches between mosaic and blur
    function chooseTool(id) {
        if (id === "mosaic" && tool === "mosaic")
            blurMode = !blurMode
        tool = id
    }

    function cycleWidth() {
        width = widths[(widths.indexOf(width) + 1) % widths.length]
    }

    // ── Recording (Tarefa 5) ──
    property bool recording: false
    property int elapsed: 0
    property string recordFile: ""
    property bool micOn: false

    // ── Notice ──
    property string toastIcon: ""
    property string toastText: ""
    property string toastFolder: ""
    property int toastSerial: 0

    // ── Folders ──
    readonly property string home: Quickshell.env("HOME")
    readonly property string tmpDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-capture`
    property string picturesDir: `${home}/Pictures/Capturas`
    property string videosDir: `${home}/Videos/Capturas`
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/quickshell`
    readonly property string statePath: `${stateDir}/capture.json`
    property bool loaded: false

    readonly property var delays: [0, 3, 5, 10]
    readonly property var widths: [2, 3, 5, 8]
    readonly property var colors: ["red", "yellow", "green", "blue", "fg"]

    // ── Session control ──
    function openCapture() {
        if (open) {
            close()
            return
        }
        start("capture")
    }

    function start(what) {
        purpose = what
        editFile = ""
        selOwner = ""
        focusName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        ShellState.close()
        ClipboardStore.close()
        if (!layout.running)
            layout.running = true   // monitors and windows, then begin()
    }

    function begin() {
        strokes = []
        redoStack = []
        tool = "arrow"
        Quickshell.execDetached(["sh", "-c", "umask 077; mkdir -p \"$1\"", "sh", tmpDir])
        open = true
        phase = purpose === "capture" && delay > 0 ? "choose" : "select"
    }

    function close() {
        tick.stop()
        settle.stop()
        open = false
        phase = "idle"
        selOwner = ""
        cleanup.restart()
    }

    function chooseMode(m) {
        mode = m
        selOwner = ""
        if (phase === "choose")
            startCountdown()
    }

    function cycleDelay() {
        delay = delays[(delays.indexOf(delay) + 1) % delays.length]
        if (open && purpose === "capture" && (phase === "choose" || phase === "select")) {
            selOwner = ""
            phase = delay > 0 ? "choose" : "select"
        }
    }

    // The overlay hides, the countdown runs on the focused monitor, then
    // (one frame later, so the countdown is not in it) the screen freezes
    function startCountdown() {
        if (delay <= 0) {
            phase = "select"
            return
        }
        countdownLeft = delay
        phase = "countdown"
        tick.restart()
    }

    function cancelCountdown() {
        close()
    }

    function toast(icon, text, folder) {
        toastIcon = icon
        toastText = text
        toastFolder = folder || ""
        toastSerial++
    }

    // A finished photo, written to the tmpfs: saved in Capturas and, when
    // asked, copied as an image. The clipboard keeps it even if saving fails.
    function finishPhoto(tmpFile, copy) {
        const name = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
        const dest = `${picturesDir}/${name}.png`
        const script = 'src=$1 dir=$2 dest=$3 copy=$4\n'
                     + 'if [ "$copy" = 1 ]; then wl-copy --type image/png < "$src" || copy=0; fi\n'
                     + 'if mkdir -p "$dir" && cp "$src" "$dest"; then saved=1; else saved=0; fi\n'
                     + 'rm -f -- "$src"\n'
                     + 'echo "$saved$copy"'
        run(["sh", "-c", script, "sh", tmpFile, picturesDir, dest, copy ? "1" : "0"], (code, out) => {
            const r = out.trim()
            if (r[0] === "1")
                toast("󰄬", r[1] === "1" ? "Copiado · salvo" : "Salvo", picturesDir)
            else
                toast("󰀦", r[1] === "1" ? "Não deu para salvar (está no clipboard)" : "Não deu para salvar o print", "")
        })
    }

    function stats() {
        return {
            open: open, purpose: purpose, phase: phase, mode: mode, kind: kind, delay: delay,
            recording: recording, elapsed: elapsed, windows: windows.length,
            tool: tool, blur: blurMode, strokes: strokes.length, redo: redoStack.length,
            monitors: Object.keys(monitors).length
        }
    }

    // ── Helpers ──
    component Job: Process {
        property var done: null
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            if (done)
                done(code, out.text)
            destroy()
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

    // Monitors (logical size, scale, active workspace) and the windows shown
    // on them, read once per opening
    Process {
        id: layout
        command: ["sh", "-c", "hyprctl -j monitors; echo @@; hyprctl -j clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n@@\n")
                let mons = []
                let clients = []
                try {
                    mons = JSON.parse(parts[0])
                    clients = JSON.parse(parts[1] || "[]")
                } catch (e) {
                    console.warn("capture: could not read the monitors from hyprctl")
                }
                const byName = {}
                const byId = {}
                for (const m of mons) {
                    const rotated = m.transform % 2 === 1
                    const info = {
                        id: m.id, x: m.x, y: m.y, scale: m.scale, ws: m.activeWorkspace ? m.activeWorkspace.id : -1,
                        w: (rotated ? m.height : m.width) / m.scale,
                        h: (rotated ? m.width : m.height) / m.scale
                    }
                    byName[m.name] = info
                    byId[m.id] = Object.assign({ name: m.name }, info)
                }
                const shown = clients.filter(c => c.mapped && !c.hidden && byId[c.monitor] && c.workspace && c.workspace.id === byId[c.monitor].ws)
                // Topmost first: floating over tiled, then the most recently focused
                shown.sort((a, b) => (b.floating - a.floating) || (a.focusHistoryID - b.focusHistoryID))
                root.monitors = byName
                root.windows = shown.map(c => ({
                    x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1],
                    monitor: byId[c.monitor].name, floating: c.floating
                }))
                root.begin()
            }
        }
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdownLeft--
            if (root.countdownLeft <= 0) {
                stop()
                root.phase = "settle"
                settle.restart()
            }
        }
    }

    // The countdown window is gone before the frame is taken
    Timer {
        id: settle
        interval: 120
        onTriggered: root.phase = "select"
    }

    // Temporary files go a moment after closing (an export may still be writing)
    Timer {
        id: cleanup
        interval: 3000
        onTriggered: {
            if (!root.open && Quickshell.env("XDG_RUNTIME_DIR"))
                Quickshell.execDetached(["rm", "-rf", "--", root.tmpDir])
        }
    }

    // ── Saved choices ──
    function save() {
        if (loaded)
            saveTimer.restart()
    }
    onModeChanged: save()
    onKindChanged: save()
    onDelayChanged: save()
    onAudioSystemChanged: save()
    onAudioMicChanged: save()
    onColorChanged: save()
    onWidthChanged: save()

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: stateFile.setText(JSON.stringify({
            mode: root.mode, kind: root.kind, delay: root.delay, audioSystem: root.audioSystem,
            audioMic: root.audioMic, color: root.color, width: root.width
        }))
    }

    function load(text) {
        try {
            const d = JSON.parse(text)
            if (typeof d !== "object" || d === null || Array.isArray(d))
                throw new Error("not an object")
            if (["area", "window", "screen"].includes(d.mode)) mode = d.mode
            if (["photo", "video"].includes(d.kind)) kind = d.kind
            if (delays.includes(d.delay)) delay = d.delay
            if (typeof d.audioSystem === "boolean") audioSystem = d.audioSystem
            if (typeof d.audioMic === "boolean") audioMic = d.audioMic
            if (colors.includes(d.color)) color = d.color
            if (widths.includes(d.width)) width = d.width
        } catch (e) {
            console.warn("capture: capture.json inválido, guardado como capture.json.bak")
            Quickshell.execDetached(["mv", "-f", "--", statePath, statePath + ".bak"])
        }
        loaded = true
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (!root.loaded)
                root.load(text())
        }
        onLoadFailed: root.loaded = true
        onSaved: Quickshell.execDetached(["chmod", "600", root.statePath])
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", "umask 077; mkdir -p \"$1\"; chmod 700 \"$1\"", "sh", stateDir])
        folders.running = true
    }

    // Pictures and Videos of this user (xdg-user-dirs), with Capturas inside
    Process {
        id: folders
        command: ["sh", "-c", "xdg-user-dir PICTURES; xdg-user-dir VIDEOS"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                if (l.length >= 2 && l[0] !== "" && l[1] !== "") {
                    root.picturesDir = `${l[0]}/Capturas`
                    root.videosDir = `${l[1]}/Capturas`
                }
            }
        }
    }
}
