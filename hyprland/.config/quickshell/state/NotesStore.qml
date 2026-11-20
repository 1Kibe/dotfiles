pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The notes of the clipboard drawer's Anotações tab. Kept in
// ~/.local/share/quickshell/clipboard/notes.json (folder 700, file 600),
// saved by itself half a second after each change. A note can be pinned
// (pinned, pinnedAt: the pinned ones go on top, in the order they were
// pinned; a file from before, without them, loads as not pinned). The
// model's order is the order dragged by hand. Note text never goes to the
// log.
Singleton {
    id: root

    // { nid, title, body, color (index in Theme.noteColors), pinned, pinnedAt }
    property ListModel model: ListModel {}
    // A new note: the Anotações tab chooses it and puts the keyboard in its
    // title, then clears this
    property string focusNid: ""
    // "Nenhuma anotação" shows only once ready
    property bool ready: false            // file read (or missing)
    // Goes up at every change, so the tab's list (a JS copy) follows
    property int revision: 0
    // The notes as plain objects (the tab's list reads this)
    function list() {
        const out = []
        for (let i = 0; i < model.count; i++) {
            const n = model.get(i)
            out.push({ nid: n.nid, title: n.title, body: n.body, color: n.color, pinned: n.pinned, pinnedAt: n.pinnedAt })
        }
        return out
    }

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

    // A new note, on top of the ones not pinned (the model's first place)
    function add() {
        const nid = `n${Date.now()}-${seq++}`
        // Each new note takes the color after the newest one
        const last = model.count > 0 ? model.get(0).color : -1
        model.insert(0, { nid: nid, title: "", body: "", color: (last + 1) % colorCount, pinned: false, pinnedAt: 0 })
        focusNid = nid
        save()
        return nid
    }

    // Called by the note's editor on every keystroke; an unchanged value is
    // not saved
    function update(nid, field, value) {
        const i = indexOf(nid)
        if (i < 0 || model.get(i)[field] === value)
            return
        model.setProperty(i, field, value)
        save()
    }

    function setColor(nid, c) {
        const i = indexOf(nid)
        if (i >= 0 && c >= 0 && c < colorCount && model.get(i).color !== c) {
            model.setProperty(i, "color", c)
            save()
        }
    }

    // Pinned: to the top (after the ones pinned before); unpinned: back
    // among the others where it is in the model
    function togglePin(nid) {
        const i = indexOf(nid)
        if (i < 0)
            return
        const on = !model.get(i).pinned
        model.setProperty(i, "pinned", on)
        model.setProperty(i, "pinnedAt", on ? Date.now() + seq++ / 1000 : 0)
        save()
    }

    // A drag on the tab's list: `nid` to the place of `target`, only inside
    // its group (pinned among the pinned, the others among the others)
    function reorder(nid, target) {
        const a = indexOf(nid), b = indexOf(target)
        if (a < 0 || b < 0 || a === b)
            return
        const pa = model.get(a).pinned, pb = model.get(b).pinned
        if (pa !== pb)
            return
        if (!pa) {
            model.move(a, b, 1)
        } else {
            // The pinned order is pinnedAt's: rewrite it in the new order
            const pins = list().filter(n => n.pinned).sort((x, y) => x.pinnedAt - y.pinnedAt).map(n => n.nid)
            const from = pins.indexOf(nid), to = pins.indexOf(target)
            pins.splice(to, 0, pins.splice(from, 1)[0])
            const base = Math.min(...pins.map(id => model.get(indexOf(id)).pinnedAt))
            pins.forEach((id, k) => model.setProperty(indexOf(id), "pinnedAt", base + k))
        }
        save()
    }

    function remove(nid) {
        const i = indexOf(nid)
        if (i >= 0) {
            model.remove(i)
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
        revision++
        saveTimer.restart()
    }

    function writeNow() {
        const list = []
        for (let i = 0; i < model.count; i++) {
            const n = model.get(i)
            list.push({ nid: n.nid, title: n.title, body: n.body, color: n.color, pinned: n.pinned, pinnedAt: n.pinnedAt })
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
                    color: Math.abs(Number(n.color) || 0) % colorCount,
                    // A file from before has neither: not pinned
                    pinned: n.pinned === true,
                    pinnedAt: n.pinned === true && Number(n.pinnedAt) > 0 ? Number(n.pinnedAt) : 0
                })
            }
        } catch (e) {
            console.warn("clipboard: notes.json inválido, guardado como notes.json.bak")
            Quickshell.execDetached(["mv", "-f", "--", path, path + ".bak"])
        }
        ready = true
        revision++
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
