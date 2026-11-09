pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quick notes of the clipboard overlay (post-its above the strip). Kept in
// ~/.local/share/quickshell/clipboard/notes.json (folder 700, file 600),
// saved by itself half a second after each change. A ListModel, so moving a
// note keeps its card (drag to reorder). Note text never goes to the log.
Singleton {
    id: root

    // { nid, title, body, color (index in Theme.noteColors) }
    // The model of the GridView in NotesGrid, used as is
    property ListModel model: ListModel {}
    // Cleared by the NoteCard that takes it (NotesGrid)
    property string focusNid: ""          // new note: its card takes the keyboard
    // NotesGrid shows "Nenhuma nota ainda" only once ready
    property bool ready: false            // file read (or missing)

    readonly property string dataDir: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/quickshell/clipboard`
    readonly property string path: `${dataDir}/notes.json`
    // Length of Theme.noteColors
    readonly property int colorCount: 5
    property int seq: 0                   // keeps ids apart within one millisecond

    function indexOf(nid) {
        for (let i = 0; i < model.count; i++) {
            if (model.get(i).nid === nid)
                return i
        }
        return -1
    }

    function add() {
        const nid = `n${Date.now()}-${seq++}`
        // Each new note takes the color after the last one
        const last = model.count > 0 ? model.get(model.count - 1).color : -1
        model.append({ nid: nid, title: "", body: "", color: (last + 1) % colorCount })
        // Its card sees this when created and starts editing
        focusNid = nid
        save()
        return nid
    }

    // Called by NoteCard on every keystroke; an unchanged value is not saved
    function update(nid, field, value) {
        const i = indexOf(nid)
        if (i < 0 || model.get(i)[field] === value)
            return
        model.setProperty(i, field, value)
        save()
    }

    function cycleColor(nid) {
        const i = indexOf(nid)
        if (i >= 0) {
            model.setProperty(i, "color", (model.get(i).color + 1) % colorCount)
            save()
        }
    }

    function remove(nid) {
        const i = indexOf(nid)
        if (i >= 0) {
            model.remove(i)
            save()
        }
    }

    // Called by NotesGrid while a note is dragged over another slot; a
    // ListModel move keeps the dragged card alive
    function move(from, to) {
        if (from !== to && from >= 0 && to >= 0 && from < model.count && to < model.count) {
            model.move(from, to, 1)
            save()
        }
    }

    // The body (or the title of a note without body)
    function copy(nid) {
        const i = indexOf(nid)
        if (i < 0)
            return
        const n = model.get(i)
        const text = n.body !== "" ? n.body : n.title
        // Through the stdin of a ClipboardStore job, never on a command line
        if (text !== "")
            ClipboardStore.run(["wl-copy"], text)
    }

    // Debounced: while typing, the file is written once typing stops
    function save() {
        saveTimer.restart()
    }

    function writeNow() {
        const list = []
        for (let i = 0; i < model.count; i++) {
            const n = model.get(i)
            list.push({ nid: n.nid, title: n.title, body: n.body, color: n.color })
        }
        file.setText(JSON.stringify(list))
    }

    // Saved notes go first; a note created before the file was read stays
    // after them (the read never wipes it)
    function load(text) {
        let at = 0
        try {
            const data = JSON.parse(text)
            if (!Array.isArray(data))
                throw new Error("not a list")
            for (const n of data) {
                // Every field is checked, so a hand-edited file cannot break the cards
                model.insert(at++, {
                    nid: String(n.nid || `n${Date.now()}-${seq++}`),
                    title: String(n.title || ""),
                    body: String(n.body || ""),
                    color: Math.abs(Number(n.color) || 0) % colorCount
                })
            }
        } catch (e) {
            console.warn("clipboard: notes.json inválido, guardado como notes.json.bak")
            Quickshell.execDetached(["mv", "-f", "--", path, path + ".bak"])
        }
        ready = true
        // Saved notes and notes made before the read: write both together
        if (at > 0 && at < model.count)
            save()
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root.writeNow()
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        atomicWrites: true
        // Read once at start: later saves must not rebuild the cards being edited
        onLoaded: {
            if (!root.ready)
                root.load(text())
        }
        onLoadFailed: root.ready = true    // no notes yet
        // An atomic write makes a new file, so the mode is set after every save
        onSaved: Quickshell.execDetached(["chmod", "600", root.path])
    }
}
