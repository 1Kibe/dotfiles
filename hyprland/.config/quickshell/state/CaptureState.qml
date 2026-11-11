pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../settings/validate.js" as Validate

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
    // The focused monitor's overlay is showing (its frozen frame is taken):
    // only then the pill opens from the bar, which is not in the overlay and
    // would end up in the frame (bar/CapturePanel)
    property bool barReady: false
    // The pill's outline on the focused monitor's frame (bar/CapturePanel),
    // in that screen's coordinates: the overlay keeps its veil out of it
    property var pill: ({ x: 0, y: 0, path: "" })
    // The bar's shape on the focused monitor (Bar.qml: its bottom corners and
    // ends stretched to the screen's edge), for the same hole
    property var barShape: ({ cornerLeft: -1, cornerRight: -1, stretchLeft: 0, stretchRight: 0 })
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

    // ── Recording (gpu-screen-recorder) ──
    property bool recording: false
    property int elapsed: 0               // seconds
    property string recordFile: ""
    property bool micOn: false            // the microphone is in this recording
    property bool isVm: false             // no GPU encoder: -encoder cpu
    property var pendingRecord: null      // { geometry, screen } waiting for the countdown
    property real recordStart: 0
    property bool stopping: false

    // ── Card of a quick print (hypr-print) ──
    property string cardFile: ""          // checked path inside the Capturas folder
    property int cardSerial: 0

    // ── Notice ──
    property string toastIcon: ""
    property string toastText: ""
    property string toastFolder: ""
    property string toastVideo: ""        // the saved recording, checked again before it opens
    property int toastSerial: 0

    // ── Folders ──
    readonly property string home: Quickshell.env("HOME")
    readonly property string tmpDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-capture`
    // Configurações → Captura e clipboard: the folders, the files' name, the
    // OCR language, the defaults of each opening and whether Enter copies
    readonly property bool settingsReady: SettingsStore.ready
    // While a folder is the schema's default, this user's own (localized)
    // Pictures/Videos folder is used (xdg-user-dirs, below); a folder chosen
    // in the settings is used as it is
    property string xdgPictures: `${home}/Pictures/Capturas`
    property string xdgVideos: `${home}/Videos/Capturas`
    function folder(key, xdg) {
        if (!settingsReady || SettingsStore.get(key) === SettingsStore.defaults[key])
            return xdg
        return Validate.expandPath(SettingsStore.get(key), home)
    }
    readonly property string picturesDir: folder("captureDir", xdgPictures)
    readonly property string videosDir: folder("videoDir", xdgVideos)
    readonly property string namePattern: settingsReady ? SettingsStore.get("captureName") : "yyyy-MM-dd_HH-mm-ss"
    // One of the schema's options only ("por+eng", "por", "eng")
    readonly property string ocrLang: settingsReady ? SettingsStore.get("ocrLang") : "por+eng"
    readonly property bool copyOnEnter: !settingsReady || SettingsStore.get("captureCopy") === true
    // The name of a new file (the schema lets only date fields and "-_."
    // into the pattern, so the name is digits and separators)
    function fileName() {
        return Qt.formatDateTime(new Date(), namePattern)
    }
    // For hypr-print (the quick prints, IPC "capture target"): where and how
    // it saves, as JSON
    function target() {
        return JSON.stringify({ dir: picturesDir, name: fileName(), copy: copyOnEnter })
    }
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/quickshell`
    readonly property string statePath: `${stateDir}/capture.json`
    property bool loaded: false

    readonly property var delays: [0, 3, 5, 10]
    readonly property var widths: [2, 3, 5, 8]
    readonly property var colors: ["red", "yellow", "green", "blue", "fg"]

    // ── Session control ──
    // Mode used to pick: OCR always takes an area
    readonly property string pickMode: purpose === "ocr" ? "area" : mode

    // Super+Shift+T, or the OCR button of the bar: pick an area, its text
    // goes to the clipboard
    function openOcr() {
        if (open && purpose === "ocr") {
            close()
            return
        }
        if (open) {
            purpose = "ocr"
            selOwner = ""
            strokes = []
            redoStack = []
            if (phase === "choose")
                phase = "select"   // no delay for OCR
            return
        }
        start("ocr")
    }

    // The area as an image in the tmpfs: tesseract (ocrLang, 15 s at most) and
    // wl-copy run together in their own process, so the text never reaches
    // the shell or a log; only the number of lines comes back. The picture
    // is removed on any way out.
    function runOcr(imageFile) {
        const script = 'f=$1\n'
            + 'trap \'rm -f -- "$f"\' EXIT\n'
            + 'chmod 600 "$f" 2>/dev/null\n'
            + 'command -v tesseract >/dev/null 2>&1 || exit 3\n'
            + 'case "$2" in por+eng|por|eng) ;; *) exit 5 ;; esac\n'
            + 'text=$(timeout 15 tesseract "$f" - -l "$2" 2>/dev/null); rc=$?\n'
            + '[ "$rc" -eq 124 ] && exit 4\n'
            + '[ "$rc" -eq 0 ] || exit 5\n'
            + 'text=$(printf "%s" "$text" | tr -d "\\f" | sed -e "s/[[:space:]]*$//" -e "/./,\\$!d")\n'
            + 'n=$(printf "%s\\n" "$text" | grep -c .)\n'
            + '[ "$n" -gt 0 ] || { echo 0; exit 0; }\n'
            + 'printf "%s" "$text" | wl-copy || exit 6\n'
            + 'echo "$n"'
        run(["sh", "-c", script, "sh", imageFile, ocrLang], (code, out) => {
            const n = parseInt(out.trim())
            if (code === 3)
                toast("󰀦", "OCR precisa do tesseract", "")
            else if (code !== 0 || isNaN(n))
                toast("󰀦", "Não deu para ler o texto", "")
            else if (n === 0)
                toast("󱄽", "Nenhum texto encontrado", "")
            else
                toast("󰄬", n === 1 ? "Texto copiado · 1 linha" : `Texto copiado · ${n} linhas`, "")
        })
    }

    function openCapture() {
        if (open) {
            close()
            return
        }
        start("capture")
    }

    // The only check of a path that came from outside (the "card" IPC can be
    // called by any process of the user): the canonical path (symlinks and
    // ".." resolved) must be a regular .png inside the canonical Capturas
    // folder. Prints that path, or nothing.
    readonly property string checkScript: 'd=$(realpath -e -- "$1" 2>/dev/null) || exit 0\n'
        + 'f=$(realpath -e -- "$2" 2>/dev/null) || exit 0\n'
        + 'case "$f" in "$d"/*.png) [ -f "$f" ] && printf %s "$f" ;; esac'
    // The same check for a recording: a .mp4 inside the Capturas of Videos
    readonly property string checkVideoScript: checkScript.replace('"$d"/*.png)', () => '"$d"/*.mp4)')

    // A quick print was taken: show its card (only for a file in Capturas)
    function showCard(path) {
        run(["sh", "-c", checkScript, "sh", picturesDir, path], (code, out) => {
            if (out === "") {
                console.warn("capture: card ignorado (não é um PNG da pasta Capturas)")
                return
            }
            cardFile = out
            focusName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : focusName
            cardSerial++
        })
    }

    // The card's pencil: the print opens in the annotation bar
    function openEditor(path) {
        if (open || path === "" || path !== cardFile)
            return
        editFile = cardFile
        purpose = "edit"
        selOwner = ""
        focusName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        barReady = false
        ShellState.close()
        ClipboardStore.close()
        if (!layout.running)
            layout.running = true
    }

    // The card's folder button: Capturas in the file manager
    function openFolder() {
        Quickshell.execDetached(["xdg-open", picturesDir])
    }

    // Trash (not deleted for good); the copy in the clipboard stays
    function trashCard(path) {
        if (path === "" || path !== cardFile)
            return
        run(["sh", "-c", checkScript + '\n', "sh", picturesDir, path], (code, out) => {
            if (out === "")
                return
            Quickshell.execDetached(["gio", "trash", "--", out])
            cardFile = ""
        })
    }

    function start(what) {
        purpose = what
        // Each opening starts from the settings' defaults; the bar may
        // change them for this capture
        if (settingsReady) {
            delay = SettingsStore.get("captureDelay")
            audioSystem = SettingsStore.get("recordSystemAudio") === true
            audioMic = SettingsStore.get("recordMic") === true
        }
        editFile = ""
        selOwner = ""
        focusName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        barReady = false
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
        phase = purpose === "capture" && delay > 0 && kind === "photo" ? "choose" : "select"
    }

    function close() {
        tick.stop()
        settle.stop()
        pendingRecord = null      // a cancelled countdown records nothing
        open = false
        phase = "idle"
        barReady = false
        selOwner = ""
        cleanup.restart()
    }

    function chooseMode(m) {
        if (purpose === "ocr")
            purpose = "capture"
        mode = m
        selOwner = ""
        if (phase === "choose")
            startCountdown()
    }

    function cycleDelay() {
        delay = delays[(delays.indexOf(delay) + 1) % delays.length]
        if (open && purpose === "capture" && kind === "photo" && (phase === "choose" || phase === "select")) {
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

    function toast(icon, text, folder, video) {
        toastIcon = icon
        toastText = text
        toastFolder = folder || ""
        toastVideo = video || ""
        toastSerial++
    }

    // The "Vídeo salvo" notice's play button: the recording opens in mpv,
    // only when it is still a .mp4 inside the Capturas folder of Videos
    function openVideo(path) {
        if (path === "" || path !== toastVideo)
            return
        run(["sh", "-c", checkVideoScript, "sh", videosDir, path], (code, out) => {
            if (out === "") {
                console.warn("capture: vídeo ignorado (não é um MP4 da pasta Capturas)")
                return
            }
            Quickshell.execDetached(["mpv", "--", out])
        })
    }

    // A finished photo, written to the tmpfs: saved in Capturas and, when
    // asked, copied as an image. The clipboard keeps it even if saving fails.
    function finishPhoto(tmpFile, copy) {
        if (purpose === "edit") {
            finishEdit(tmpFile, copy)
            return
        }
        const name = fileName()
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

    // The edited print replaces the same file, checked again right before
    // writing (it is never written outside Capturas)
    function finishEdit(tmpFile, copy) {
        const script = 'src=$3 copy=$4\n' + checkScript.replace(/printf %s "\$f"/, 'dest=$f') + '\n'
                     + '[ -n "${dest:-}" ] || { rm -f -- "$src"; echo 0; exit 0; }\n'
                     + 'if [ "$copy" = 1 ]; then wl-copy --type image/png < "$src" || copy=0; fi\n'
                     + 'if cp "$src" "$dest"; then saved=1; else saved=0; fi\n'
                     + 'rm -f -- "$src"\n'
                     + 'echo "$saved$copy"'
        run(["sh", "-c", script, "sh", picturesDir, editFile, tmpFile, copy ? "1" : "0"], (code, out) => {
            const r = out.trim()
            if (r[0] === "1") {
                toast("󰄬", r[1] === "1" ? "Copiado · print atualizado" : "Print atualizado", picturesDir)
                cardSerial++   // the card shows the new picture
            } else {
                toast("󰀦", "Não deu para salvar o print", "")
            }
        })
    }

    // ── Recording ──

    // Super+Alt+R: stops, or records the focused monitor with the last
    // sound choices and no delay
    function toggleRecord() {
        if (recording) {
            stopRecord()
            return
        }
        if (open)
            close()
        const monitor = Hyprland.focusedMonitor
        if (monitor)
            recordLater(null, monitor.name)
    }

    // From the capture bar in Vídeo: the chosen area (global logical
    // coordinates; null = the whole monitor). With a delay the countdown runs
    // first; the overlay is gone before the recording starts.
    function recordSelection(geometry, screen) {
        if (recording)
            return
        if (delay > 0) {
            pendingRecord = { geometry: geometry, screen: screen }
            countdownLeft = delay
            phase = "countdown"     // hides the overlay, shows the countdown
            tick.restart()
            return
        }
        close()
        recordLater(geometry, screen)
    }

    function recordLater(geometry, screen) {
        pendingRecord = { geometry: geometry, screen: screen }
        recordDelay.restart()
    }

    function startRecord(geometry, screen) {
        if (recording || recorder.running)
            return
        const name = fileName()
        recordFile = `${videosDir}/${name}.mp4`
        const args = ["gpu-screen-recorder", "-f", "30", "-k", "h264", "-c", "mp4", "-o", recordFile]
        if (geometry)
            args.push("-w", "region", "-region", `${Math.round(geometry.w)}x${Math.round(geometry.h)}+${Math.round(geometry.x)}+${Math.round(geometry.y)}`)
        else
            args.push("-w", screen)
        // System sound, microphone, both mixed in one track, or none
        if (audioSystem && audioMic)
            args.push("-a", "default_output|default_input")
        else if (audioSystem)
            args.push("-a", "default_output")
        else if (audioMic)
            args.push("-a", "default_input")
        if (isVm)
            args.push("-encoder", "cpu")
        micOn = audioMic
        stopping = false
        // exec: the recorder itself gets the SIGINT that stops it
        recorder.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "sh", videosDir].concat(args)
        recordStart = Date.now()
        elapsed = 0
        recording = true
        recorder.running = true
    }

    // SIGINT: the recorder stops and closes the MP4 properly
    function stopRecord() {
        if (recorder.running) {
            stopping = true
            recorder.signal(2)
        }
    }

    function stats() {
        return {
            open: open, purpose: purpose, phase: phase, mode: mode, kind: kind, delay: delay,
            recording: recording, elapsed: elapsed, micOn: micOn, windows: windows.length,
            tool: tool, blur: blurMode, strokes: strokes.length, redo: redoStack.length,
            card: cardFile !== "", cardSerial: cardSerial,
            toast: toastText, toastSerial: toastSerial,   // notices never carry content
            toastVideo: toastVideo !== "",
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
                if (root.pendingRecord) {
                    const p = root.pendingRecord
                    root.close()
                    root.recordLater(p.geometry, p.screen)
                    return
                }
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
    onKindChanged: {
        save()
        // In Vídeo the delay comes before recording: pick the area right away
        if (open && kind === "video" && phase === "choose")
            phase = "select"
    }
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

    // The overlay (or the countdown) is off the screen before recording
    Timer {
        id: recordDelay
        interval: 250
        onTriggered: {
            const p = root.pendingRecord
            root.pendingRecord = null
            if (p)
                root.startRecord(p.geometry, p.screen)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = Math.floor((Date.now() - root.recordStart) / 1000)
    }

    Process {
        id: recorder
        stderr: StdioCollector {
            id: recorderErr
        }
        onExited: code => {
            const quick = Date.now() - root.recordStart < 1000
            root.recording = false
            root.elapsed = 0
            if (!quick && (code === 0 || root.stopping)) {
                root.toast("󰕧", "Vídeo salvo", root.videosDir, root.recordFile)
            } else {
                // Only the recorder's messages, with any path taken out
                const why = recorderErr.text.trim().split("\n").slice(-3).join(" | ").replace(/\/\S+/g, "<caminho>")
                console.warn(`capture: o gravador saiu (código ${code}): ${why}`)
                root.toast("󰀦", "Não deu para gravar", "")
            }
        }
    }

    // A VM has no GPU encoder for the recorder
    Process {
        running: true
        command: ["systemd-detect-virt", "--vm", "--quiet"]
        onExited: code => root.isVm = code === 0
    }

    // The shell is closing (logout, reload): stop the recording properly
    Component.onDestruction: stopRecord()

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
                    root.xdgPictures = `${l[0]}/Capturas`
                    root.xdgVideos = `${l[1]}/Capturas`
                }
            }
        }
    }
}
