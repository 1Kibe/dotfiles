pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/palettes.js" as Palettes

// The themes of the repo: themes/index.json (the ids, in order; the folder is
// never listed) and each themes/<id>.json, checked by theme/palettes.js. A
// file that does not pass stays out (a line in the log, never its content).
// ready: every listed file answered (read or failed).
Singleton {
    id: root

    // At most this many themes, each file at most this many bytes
    readonly property int maxThemes: 32
    readonly property int maxBytes: 65536

    property var ids: []
    property var found: ({})
    property int answered: 0
    readonly property bool ready: indexRead && answered === ids.length
    property bool indexRead: false
    // The checked themes, in the index's order
    readonly property var themes: ids.filter(id => found[id] !== undefined).map(id => found[id])

    function get(id) {
        return typeof id === "string" && Object.prototype.hasOwnProperty.call(found, id) ? found[id] : null
    }

    function readIndex(text) {
        let list = []
        try {
            list = text.length <= maxBytes ? JSON.parse(text) : []
        } catch (e) {
            list = []
        }
        if (!Array.isArray(list)) {
            console.warn("temas: themes/index.json inválido")
            list = []
        }
        const out = []
        for (const id of list) {
            if (typeof id === "string" && Palettes.THEME_NAME.test(id) && !out.includes(id) && out.length < maxThemes)
                out.push(id)
        }
        found = ({})
        answered = 0
        ids = out
        indexRead = true
    }
    function readTheme(id, text) {
        let theme = null
        try {
            const r = text.length <= maxBytes ? Palettes.validateTheme(JSON.parse(text)) : { ok: false }
            // The file's own id has to be the one listed
            if (r.ok && r.theme.id === id)
                theme = r.theme
        } catch (e) {
            theme = null
        }
        if (theme === null)
            console.warn("temas: tema recusado: " + id)
        else {
            const f = Object.assign({}, found)
            f[id] = theme
            found = f
        }
        answered++
    }

    FileView {
        path: Quickshell.shellPath("themes/index.json")
        printErrors: false
        onLoaded: root.readIndex(text())
        onLoadFailed: root.readIndex("")
    }
    Instantiator {
        model: root.ids
        delegate: FileView {
            required property string modelData
            path: Quickshell.shellPath("themes/" + modelData + ".json")
            printErrors: false
            onLoaded: root.readTheme(modelData, text())
            onLoadFailed: root.readTheme(modelData, "")
        }
    }
}
