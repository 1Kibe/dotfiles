pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history for the Super+V overlay (clipboard/ClipboardOverlay):
// the last 100 cliphist entries, their kind, image previews, pinned items
// and the copy/delete/clear actions. Copied content never goes to the log.
//
// - History: cliphist (stored by autostart.lua; it already skips items that
//   password managers mark as sensitive).
// - Card text: one batch per opening decodes the start (~4 KB) of each text.
// - Image previews: decoded only for cards on screen, into a tmpfs folder
//   removed on closing.
// - Pins: their own file (pins.json + image files), so "Limpar" keeps them.
Singleton {
    id: root

    property bool open: false
    property string openOn: ""            // monitor name
    // { id, kind: text|link|code|color|image, text, mime, width, height }
    property var items: []
    // { pid, kind, text, file, mime, width, height }
    property var pins: []
    property bool loaded: false           // list read at least once since opening
    property int loadMs: 0                // list + first text batch (first screen), for the tests
    property int fullMs: 0                // until every text is decoded
    property var decodeRest: []           // text ids of the second batch
    readonly property int firstBatch: 16  // about what fits on screen, decoded first
    property var previews: ({})           // cliphist id -> file URL
    property var pendingPreviews: []

    readonly property string runDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-clip`
    readonly property string dataDir: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/quickshell/clipboard`
    readonly property string pinsPath: `${dataDir}/pins.json`

    property real loadStart: 0

    function toggle(monitor) {
        if (open && openOn === monitor) {
            close()
            return
        }
        ShellState.close()
        openOn = monitor
        open = true
        refresh()
    }

    function close() {
        open = false
    }

    // ── Kind of an entry, from its text ──
    function kindOf(text) {
        const t = text.trim()
        if (/^https?:\/\/\S+$/.test(t))
            return "link"
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t) || /^rgba?\([\d\s.,%]+\)$/.test(t))
            return "color"
        const lines = t.split("\n")
        if (lines.length >= 2 && (/[{};]\s*$/m.test(t) || /^(\t| {2,})\S/m.test(t)))
            return "code"
        return "text"
    }

    // "rgb(250, 189, 47)" and "#fabd2f" as a color
    function colorOf(text) {
        const t = text.trim()
        const m = t.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+%?)\s*)?\)$/)
        if (m) {
            let a = m[4] === undefined ? 1 : m[4].endsWith("%") ? parseFloat(m[4]) / 100 : Number(m[4])
            return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, a)
        }
        return t
    }

    // ── History ──
    function refresh() {
        loaded = false
        fullMs = 0
        decodeRest = []
        loadStart = Date.now()
        if (!list.running)
            list.running = true
    }

    function readList(text) {
        const out = []
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t")
            if (tab < 1)
                continue
            const id = line.slice(0, tab)
            const preview = line.slice(tab + 1)
            const img = preview.match(/^\[\[ binary data .+ (\w+) (\d+)x(\d+) \]\]$/)
            if (img)
                out.push({ id: id, kind: "image", text: "", mime: `image/${img[1]}`, width: Number(img[2]), height: Number(img[3]) })
            else
                out.push({ id: id, kind: kindOf(preview), text: preview, mime: "", width: 0, height: 0 })
            if (out.length >= 100)
                break
        }
        items = out
        // cliphist locks its database, so decodes run one after another: the
        // cards on screen first, the rest (for the search) right after
        const texts = out.filter(i => i.kind !== "image").map(i => i.id)
        decodeRest = texts.slice(firstBatch)
        if (texts.length > 0) {
            startDecode(decode, texts.slice(0, firstBatch))
        } else {
            finishLoad()
            fullMs = loadMs
        }
    }

    // The first batch may still be closing when the second starts: two processes
    function startDecode(proc, ids) {
        proc.command = ["sh", "-c", "for id; do printf '\\036%s\\n' \"$id\"; cliphist decode \"$id\" | head -c 4096; done", "sh"].concat(ids)
        proc.running = true
    }

    // Batch output: \x1e id \n text, for each text entry
    function readTexts(text) {
        const byId = {}
        for (const part of text.split("\x1e")) {
            const nl = part.indexOf("\n")
            if (nl < 1)
                continue
            // A cut in the middle of a character shows as U+FFFD: drop it
            byId[part.slice(0, nl)] = part.slice(nl + 1).replace(/�$/, "").replace(/\n$/, "")
        }
        items = items.map(i => {
            if (byId[i.id] === undefined)
                return i
            const t = byId[i.id]
            return Object.assign({}, i, { text: t, kind: kindOf(t) })
        })
        if (!loaded)
            finishLoad()
        if (decodeRest.length > 0) {
            const next = decodeRest
            decodeRest = []
            startDecode(decodeMore, next)
        } else {
            fullMs = Date.now() - loadStart
        }
    }

    function finishLoad() {
        loadMs = Date.now() - loadStart
        loaded = true
    }

    // ── Image previews (tmpfs, only cards on screen) ──
    function requestPreview(id) {
        if (previews[id] !== undefined || pendingPreviews.includes(id))
            return
        pendingPreviews = pendingPreviews.concat([id])
        previewBatch.restart()
    }

    function dropPreviews() {
        previews = {}
        pendingPreviews = []
        if (Quickshell.env("XDG_RUNTIME_DIR"))
            Quickshell.execDetached(["rm", "-rf", "--", runDir])
    }

    // ── Actions (each one its own short process) ──
    function copy(entry) {
        if (entry.pid !== undefined) {
            if (entry.kind === "image")
                run(["sh", "-c", "wl-copy --type \"$2\" < \"$1\"", "sh", entry.file, entry.mime])
            else
                run(["wl-copy"], entry.text)
        } else if (entry.kind === "image") {
            run(["sh", "-c", "cliphist decode \"$1\" | wl-copy --type \"$2\"", "sh", entry.id, entry.mime])
        } else {
            run(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entry.id])
        }
        close()
    }

    function remove(entry) {
        if (entry.pid !== undefined) {
            unpin(entry)
            return
        }
        run(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", entry.id])
        items = items.filter(i => i.id !== entry.id)
    }

    function wipe() {
        run(["cliphist", "wipe"])
        items = []
        dropPreviews()
    }

    function isPinned(entry) {
        return entry.pid !== undefined
    }

    // Pinning keeps the whole content (not only the 4 KB of the card)
    function pin(entry) {
        if (entry.pid !== undefined)
            return
        const pid = `p${Date.now()}`
        if (entry.kind === "image") {
            const file = `${dataDir}/${pid}`
            run(["sh", "-c", "umask 077; cliphist decode \"$1\" > \"$2\"", "sh", entry.id, file], "", code => {
                if (code === 0)
                    savePins([{ pid: pid, kind: "image", text: "", file: file, mime: entry.mime, width: entry.width, height: entry.height }].concat(pins))
            })
        } else {
            run(["cliphist", "decode", entry.id], "", (code, out) => {
                if (code === 0)
                    savePins([{ pid: pid, kind: kindOf(out), text: out.replace(/\n$/, ""), file: "", mime: "", width: 0, height: 0 }].concat(pins))
            })
        }
    }

    function unpin(entry) {
        if (entry.kind === "image" && entry.file.startsWith(dataDir + "/"))
            Quickshell.execDetached(["rm", "-f", "--", entry.file])
        savePins(pins.filter(p => p.pid !== entry.pid))
    }

    function togglePin(entry) {
        if (entry.pid !== undefined)
            unpin(entry)
        else
            pin(entry)
    }

    function savePins(list) {
        pins = list
        pinsFile.setText(JSON.stringify(list))
    }

    function stats() {
        const byKind = {}
        for (const i of items)
            byKind[i.kind] = (byKind[i.kind] || 0) + 1
        return { open: open, loaded: loaded, items: items.length, pins: pins.length, byKind: byKind, loadMs: loadMs, fullMs: fullMs }
    }

    // Short job: command, optional stdin text, optional callback(code, stdout)
    component Job: Process {
        property string input
        property var done: null
        stdinEnabled: input !== ""
        stdout: StdioCollector {
            id: out
        }
        onStarted: {
            if (input !== "") {
                write(input)
                stdinEnabled = false
            }
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

    function run(command, input, done) {
        const job = jobComponent.createObject(root, { command: command, input: input || "", done: done || null })
        job.running = true
    }

    onOpenChanged: {
        if (!open)
            dropPreviews()
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.readList(text)
        }
        // cliphist missing or failing: an empty history
        onExited: code => {
            if (code !== 0) {
                root.items = []
                root.finishLoad()
            }
        }
    }

    Process {
        id: decode
        stdout: StdioCollector {
            onStreamFinished: root.readTexts(text)
        }
    }

    Process {
        id: decodeMore
        stdout: StdioCollector {
            onStreamFinished: root.readTexts(text)
        }
    }

    Timer {
        id: previewBatch
        interval: 30
        onTriggered: {
            if (preview.running || root.pendingPreviews.length === 0)
                return
            preview.batch = root.pendingPreviews
            root.pendingPreviews = []
            preview.command = ["sh", "-c", "d=$1; shift; mkdir -p \"$d\" && chmod 700 \"$d\" && for id; do cliphist decode \"$id\" > \"$d/$id\"; done", "sh", root.runDir].concat(preview.batch)
            preview.running = true
        }
    }

    Process {
        id: preview
        property var batch: []
        onExited: {
            const next = Object.assign({}, root.previews)
            for (const id of batch)
                next[id] = `file://${root.runDir}/${id}`
            if (root.open)
                root.previews = next
            if (root.pendingPreviews.length > 0)
                previewBatch.restart()
        }
    }

    // Pins: private folder (700) and file (600); a broken file is kept as .bak
    FileView {
        id: pinsFile
        path: root.pinsPath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text())
                root.pins = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("clipboard: pins.json inválido, guardado como pins.json.bak")
                Quickshell.execDetached(["mv", "-f", "--", root.pinsPath, root.pinsPath + ".bak"])
                root.pins = []
            }
        }
        onSaved: Quickshell.execDetached(["chmod", "600", root.pinsPath])
    }

    Component.onCompleted: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && chmod 700 \"$1\"", "sh", dataDir])
}
