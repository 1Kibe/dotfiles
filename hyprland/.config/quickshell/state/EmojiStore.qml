pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji tab of the clipboard overlay: the list comes from the system's
// emoji-test.txt (package unicode-emoji), read the first time the tab
// opens; names are the English ones from Unicode. Picking one copies it and
// keeps it among the recent ones (up to 40, in emoji-recent.json).
Singleton {
    id: root

    // { e: "😀", name: "grinning face", cat: "faces" }
    property var all: []
    // Read by EmojiGrid: "Carregando…" until loaded, a hint when missing
    property bool loaded: false
    property bool missing: false          // no emoji-test.txt (package not installed)
    property var recent: []               // emoji strings, newest first
    readonly property int maxRecent: 40

    readonly property string source: "/usr/share/unicode/emoji/emoji-test.txt"
    readonly property string dataDir: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/quickshell/clipboard`
    readonly property string recentPath: `${dataDir}/emoji-recent.json`

    // Chips of the tab. Unicode groups -> chip ("Travel & Places" joins the
    // objects; "Component", the bare skin tones, is left out)
    readonly property var categories: [
        { key: "recent", label: "Recentes" },
        { key: "faces", label: "Rostos" },
        { key: "people", label: "Gestos" },
        { key: "animals", label: "Animais" },
        { key: "food", label: "Comida" },
        { key: "activities", label: "Atividades" },
        { key: "objects", label: "Objetos" },
        { key: "symbols", label: "Símbolos" },
        { key: "flags", label: "Bandeiras" }
    ]
    readonly property var groups: ({
        "Smileys & Emotion": "faces",
        "People & Body": "people",
        "Animals & Nature": "animals",
        "Food & Drink": "food",
        "Activities": "activities",
        "Travel & Places": "objects",
        "Objects": "objects",
        "Symbols": "symbols",
        "Flags": "flags"
    })

    // Called by ClipStrip when the Emoji tab opens. testFile has no path
    // until then, so nothing is read for people who never use the tab
    function ensureLoaded() {
        if (!loaded && testFile.path === "")
            testFile.path = source
    }

    // "1F600 ; fully-qualified # 😀 E1.0 grinning face"; skin tone
    // variants are left out (the base emoji stays)
    function parse(text) {
        const out = []
        let cat = ""
        for (const line of text.split("\n")) {
            // A group without a chip (Component) sets "" and its lines are skipped
            if (line.startsWith("# group: ")) {
                cat = groups[line.slice(9).trim()] || ""
                continue
            }
            if (cat === "" || !line.includes("; fully-qualified"))
                continue
            // After "#": 1 the emoji, then its version (E1.0), 2 the name
            const m = line.match(/#\s*(\S+)\s+E[\d.]+\s+(.+)$/)
            if (!m || m[2].includes("skin tone"))
                continue
            out.push({ e: m[1], name: m[2].trim(), cat: cat })
        }
        all = out
        loaded = true
    }

    // Emoji of a chip, or every emoji whose name has all the words searched
    function list(cat, query) {
        const q = query.trim().toLowerCase()
        if (q !== "") {
            // Unicode names are already lowercase; a search covers every group
            const words = q.split(/\s+/)
            return all.filter(x => words.every(w => x.name.includes(w)))
        }
        // Recent ones keep their order; one not in the list (older file)
        // still shows, without a name
        if (cat === "recent")
            return recent.map(e => all.find(x => x.e === e) || { e: e, name: "", cat: "recent" })
        return all.filter(x => x.cat === cat)
    }

    // Called by EmojiGrid (click or Enter); closes the overlay like a card copy
    function pick(e) {
        ClipboardStore.run(["wl-copy"], e)
        // Moved to the front, no repeats; saved at once
        recent = [e].concat(recent.filter(x => x !== e)).slice(0, maxRecent)
        recentFile.setText(JSON.stringify(recent))
        ClipboardStore.close()
    }

    FileView {
        id: testFile
        // Set by ensureLoaded()
        path: ""
        printErrors: false
        onLoaded: root.parse(text())
        onLoadFailed: {
            root.missing = true
            root.loaded = true
        }
    }

    // Recent ones: read once; picks made before the read stay first
    FileView {
        id: recentFile
        path: root.recentPath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const saved = JSON.parse(text())
                if (Array.isArray(saved))
                    root.recent = root.recent.concat(saved.filter(e => typeof e === "string" && !root.recent.includes(e))).slice(0, root.maxRecent)
            } catch (e) {
                console.warn("clipboard: emoji-recent.json inválido, guardado como emoji-recent.json.bak")
                Quickshell.execDetached(["mv", "-f", "--", root.recentPath, root.recentPath + ".bak"])
            }
        }
        // Private like the pins and notes; set again after each atomic write
        onSaved: Quickshell.execDetached(["chmod", "600", root.recentPath])
    }
}
