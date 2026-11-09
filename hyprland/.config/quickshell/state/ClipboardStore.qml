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

    // Read by ClipboardOverlay (shown, screen); set by toggle() and close()
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
    // Read by ClipCard; "" means no preview (the card shows a generic icon)
    property var previews: ({})           // cliphist id -> file URL
    // Ids asked by ClipCards, decoded together by previewBatch
    property var pendingPreviews: []

    readonly property string runDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-clip`
    // One folder per opening: removing the last one (in the background)
    // never touches the previews of the next
    property string previewDir: ""
    property var oldPreviewDirs: []       // waiting to be removed
    readonly property string dataDir: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/quickshell/clipboard`
    readonly property string pinsPath: `${dataDir}/pins.json`

    property real loadStart: 0
    property int seq: 0                   // keeps pin ids apart within one millisecond

    // Called by the clipboard IPC in shell.qml (Super+V) with the focused
    // monitor; pressed again on the same monitor it closes
    function toggle(monitor) {
        if (open && openOn === monitor) {
            close()
            return
        }
        // One popup at a time: an open bar panel closes first
        ShellState.close()
        openOn = monitor
        previewDir = `${runDir}/${Date.now()}`
        open = true
        refresh()
    }

    // Also called by CaptureState when a capture starts, so the overlay
    // never ends up in the picture
    function close() {
        open = false
    }

    // ── Kind of an entry, from its text ──
    function kindOf(text) {
        const t = text.trim()
        if (/^https?:\/\/\S+$/.test(t))
            return "link"
        // #rgb, #rrggbb, #rrggbbaa, rgb() or rgba()
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t) || /^rgba?\([\d\s.,%]+\)$/.test(t))
            return "color"
        // Code: two or more lines, some ending in a brace or semicolon, or
        // starting with indentation
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
            // Alpha may be 0-1 or a percentage; missing means opaque
            let a = m[4] === undefined ? 1 : m[4].endsWith("%") ? parseFloat(m[4]) / 100 : Number(m[4])
            return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, a)
        }
        // A hex string is already a valid QML color
        return t
    }

    // ── History ──
    function refresh() {
        loaded = false
        fullMs = 0
        decodeRest = []
        loadStart = Date.now()
        // A list still running (quick reopen) is reused, not started twice
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
            // cliphist lists an image as "[[ binary data <size> <format> <w>x<h> ]]"
            const img = preview.match(/^\[\[ binary data .+ (\w+) (\d+)x(\d+) \]\]$/)
            // A text starts with the one-line, cut preview of the list;
            // readTexts swaps it for the decoded start
            if (img)
                out.push({ id: id, kind: "image", text: "", mime: `image/${img[1]}`, width: Number(img[2]), height: Number(img[3]) })
            else
                out.push({ id: id, kind: kindOf(preview), text: preview, mime: "", width: 0, height: 0 })
            // The list is newest first, so the cut keeps the last 100
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
            // Only images (or nothing): no text to decode, the list is final
            finishLoad()
            fullMs = loadMs
        }
    }

    // The first batch may still be closing when the second starts: two processes
    function startDecode(proc, ids) {
        // Ids go as arguments, never inside the script; a \x1e byte before
        // each id lets readTexts split the output, head keeps the card text short
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
        // New objects and a new array, so the bindings on items (ClipStrip.cards)
        // see the change; the kind is guessed again from the full start
        items = items.map(i => {
            if (byId[i.id] === undefined)
                return i
            const t = byId[i.id]
            return Object.assign({}, i, { text: t, kind: kindOf(t) })
        })
        // The first batch marks the list as loaded (ClipStrip may show "empty")
        if (!loaded)
            finishLoad()
        // Second batch only after the first one: cliphist locks its database
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
        // Cards created together end up in one process (see previewBatch)
        previewBatch.restart()
    }

    // The folder goes a moment later, after the cards stopped reading it
    function dropPreviews() {
        previews = {}
        pendingPreviews = []
        // Without XDG_RUNTIME_DIR there is no safe folder to remove
        if (Quickshell.env("XDG_RUNTIME_DIR") && previewDir !== "" && !oldPreviewDirs.includes(previewDir)) {
            oldPreviewDirs = oldPreviewDirs.concat([previewDir])
            cleanup.restart()
        }
    }

    // ── Actions (each one its own short process) ──
    // Pins copy from their own text or file; history entries are decoded
    // again in full by cliphist (the card holds only the first 4 KB)
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
        // Closing gives the keyboard back to the window that will paste
        close()
    }

    function remove(entry) {
        if (entry.pid !== undefined) {
            unpin(entry)
            return
        }
        // cliphist delete reads lines in its list format ("id<tab>preview");
        // the id is enough
        run(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", entry.id])
        // Gone from the strip at once, without listing again
        items = items.filter(i => i.id !== entry.id)
    }

    // "Limpar" in ClipStrip; pins live in their own file and stay
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
        // pid marks a pin (isPinned) and names its image file
        const pid = `p${Date.now()}-${seq++}`
        if (entry.kind === "image") {
            const file = `${dataDir}/${pid}`
            run(["sh", "-c", "umask 077; cliphist decode \"$1\" > \"$2\"", "sh", entry.id, file], "", code => {
                // Listed as a pin only once the file is on disk
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
        // Only files inside our own folder are ever removed
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

    // The screen updates at once; pins.json is rewritten whole
    function savePins(list) {
        pins = list
        pinsFile.setText(JSON.stringify(list))
    }

    // Counts only, never content: the "stats" call of the clipboard IPC (shell.qml)
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
        // Text goes through stdin (never on the command line), written once
        // at start and then closed so the command sees the end of input
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
            // Each job is a throwaway object made by run()
            destroy()
        }
    }

    Component {
        id: jobComponent
        Job {}
    }

    // Also used by NotesStore and EmojiStore for wl-copy
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
        // One "id<tab>preview" line per entry, newest first
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

    // First text batch (cards on screen) and the rest; both end in readTexts
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
        id: cleanup
        // Well after the closing animation, when no card reads the files
        interval: 1500
        onTriggered: {
            // rmdir also drops runDir, unless a newer opening is using it
            Quickshell.execDetached(["sh", "-c", "d=$1; shift; rm -rf -- \"$@\"; rmdir -- \"$d\" 2>/dev/null; true", "sh", root.runDir].concat(root.oldPreviewDirs))
            root.oldPreviewDirs = []
        }
    }

    Timer {
        id: previewBatch
        // A short wait gathers the cards a scroll creates into one batch
        interval: 30
        onTriggered: {
            if (root.pendingPreviews.length === 0)
                return
            // cliphist locks its database: wait for the text batches, or a
            // decode would come back empty
            if (preview.running || decode.running || decodeMore.running) {
                restart()
                return
            }
            preview.batch = root.pendingPreviews
            root.pendingPreviews = []
            preview.dir = root.previewDir
            // Prints the ids that decoded to a non-empty file
            preview.command = ["sh", "-c", "umask 077; d=$1; shift; mkdir -p \"$d\" || exit 1; for id; do if cliphist decode \"$id\" > \"$d/$id\" && [ -s \"$d/$id\" ]; then echo \"$id\"; else rm -f -- \"$d/$id\"; fi; done", "sh", root.previewDir].concat(preview.batch)
            preview.running = true
        }
    }

    Process {
        id: preview
        // Copies taken at start: pendingPreviews and previewDir move on meanwhile
        property var batch: []
        property string dir
        stdout: StdioCollector {
            id: decoded
        }
        onExited: {
            const next = Object.assign({}, root.previews)
            const ok = decoded.text.split("\n").filter(id => id !== "")
            for (const id of batch)
                next[id] = ok.includes(id) ? `file://${dir}/${id}` : ""   // "" = generic icon
            // Only for the opening that asked (not a late batch of the last one)
            if (root.open && dir === root.previewDir)
                root.previews = next
            // Ids asked while this batch ran
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
            // Pins made before this read stay (first), the saved ones follow
            try {
                const data = JSON.parse(text())
                const saved = Array.isArray(data) ? data : []
                const made = root.pins.filter(p => !saved.some(s => s.pid === p.pid))
                root.pins = made.concat(saved)
                if (made.length > 0)
                    root.savePins(root.pins)
            } catch (e) {
                console.warn("clipboard: pins.json inválido, guardado como pins.json.bak")
                Quickshell.execDetached(["mv", "-f", "--", root.pinsPath, root.pinsPath + ".bak"])
            }
        }
        // An atomic write makes a new file, so the mode is set after every save
        onSaved: Quickshell.execDetached(["chmod", "600", root.pinsPath])
    }

    // The folder is shared with NotesStore and EmojiStore: private before
    // any of them writes there
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && chmod 700 \"$1\"", "sh", dataDir])
}
