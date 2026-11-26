pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/palettes.js" as Palettes
import "../theme/customtheme.js" as Custom

// The themes of the repo: themes/index.json (the ids, in order; the folder is
// never listed) and each themes/<id>.json, checked by theme/palettes.js. A
// file that does not pass stays out (a line in the log, never its content).
// ready: every listed file answered (read or failed). After them, the
// owner's own themes (Novo tema personalizado), out of the repo in
// ~/.local/share/dotfiles/themes: its index.json and each <id>.json, the
// same checks, ids "seu-" and six letters or digits; isOwn() tells them.
Singleton {
    id: root

    // At most this many themes, each file at most this many characters
    // (counted after the FileView read it whole: the files are the repo's
    // own, so this is a guard against a mistake, not a defense)
    readonly property int maxThemes: 32
    readonly property int maxBytes: 65536

    property var ids: []
    // id -> theme, and the ids that answered (Maps: an id like
    // "constructor" or "__proto__" is never a plain object's property)
    property var found: new Map()
    property var answeredIds: new Map()
    readonly property int answered: answeredIds.size
    readonly property bool ready: indexRead && answered === ids.length && ownIndexRead && ownAnswered === ownIds.length
    property bool indexRead: false
    // The checked themes, in the index's order, then the owner's own
    readonly property var themes: ids.filter(id => found.has(id)).map(id => found.get(id))
                                  .concat(ownIds.filter(id => ownFound.has(id)).map(id => ownFound.get(id)))

    function get(id) {
        if (typeof id !== "string")
            return null
        return found.has(id) ? found.get(id) : ownFound.has(id) ? ownFound.get(id) : null
    }
    function isOwn(id) {
        return typeof id === "string" && ownFound.has(id)
    }

    // ── The owner's own themes ──
    readonly property int maxOwn: 24
    readonly property string ownDir: `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/dotfiles/themes`
    property var ownIds: []
    property var ownFound: new Map()
    property var ownAnsweredIds: new Map()
    readonly property int ownAnswered: ownAnsweredIds.size
    property bool ownIndexRead: false
    function readOwnIndex(text) {
        let list = null
        try {
            list = text.length <= maxBytes ? JSON.parse(text) : null
        } catch (e) {
            list = null
        }
        const out = []
        if (Array.isArray(list)) {
            for (const id of list) {
                if (typeof id === "string" && Custom.OWN_ID.test(id) && !out.includes(id) && out.length < maxOwn)
                    out.push(id)
            }
        }
        ownFound = new Map()
        ownAnsweredIds = new Map()
        ownIds = out
        ownIndexRead = true
    }
    function readOwnTheme(id, text) {
        let theme = null
        try {
            const r = text.length <= maxBytes ? Palettes.validateTheme(JSON.parse(text)) : { ok: false }
            if (r.ok && r.theme.id === id)
                theme = r.theme
        } catch (e) {
            theme = null
        }
        if (theme === null)
            console.warn("temas: tema próprio recusado: " + id)
        else {
            const f = new Map(ownFound)
            f.set(id, theme)
            ownFound = f
        }
        const a = new Map(ownAnsweredIds)
        a.set(id, true)
        ownAnsweredIds = a
    }

    // Saving one (the editor's Salvar): the theme checked again here, the
    // folder made 700 and never a link, the file and the index written 600
    // through a temporary file in the folder and renamed over. done(ok, id)
    signal saveDone(bool ok, string id)
    property string saveText: ""
    readonly property string saveScript:
        'umask 077; d=$1; id=$2; index=$3\n'
        + '[ -L "$d" ] && exit 1\n'
        + 'mkdir -p -- "$d" || exit 1\n'
        + '[ -d "$d" ] && [ ! -L "$d" ] || exit 1\n'
        + 'chmod 700 -- "$d" || exit 1\n'
        + 't=$(mktemp -- "$d/.tema.XXXXXX") || exit 1\n'
        + 'cat > "$t" && chmod 600 -- "$t" && mv -f -- "$t" "$d/$id.json" || { rm -f -- "$t"; exit 1; }\n'
        + 'i=$(mktemp -- "$d/.indice.XXXXXX") || exit 1\n'
        + 'printf "%s\\n" "$index" > "$i" && chmod 600 -- "$i" && mv -f -- "$i" "$d/index.json" || { rm -f -- "$i"; exit 1; }\n'
        + 'echo ok'
    function saveOwn(theme) {
        if (saver.running || !ownIndexRead)
            return false
        const v = Palettes.validateTheme(theme)
        if (!v.ok || !Custom.OWN_ID.test(v.theme.id))
            return false
        const list = ownIds.includes(v.theme.id) ? ownIds : ownIds.concat([v.theme.id])
        if (list.length > maxOwn)
            return false
        saveText = Custom.serialize(v.theme)
        saver.command = ["sh", "-c", saveScript, "sh", ownDir, v.theme.id, JSON.stringify(list)]
        saver.stdinEnabled = true
        saver.running = true
        return true
    }
    Process {
        id: saver
        stdout: StdioCollector {
            id: saverOut
        }
        stderr: StdioCollector {}
        onRunningChanged: {
            if (running) {
                write(root.saveText)
                stdinEnabled = false
            }
        }
        onExited: code => {
            // (sh -c script sh dir id index: the id is the sixth)
            const id = saver.command.length > 5 ? saver.command[5] : ""
            const ok = code === 0 && saverOut.text.trim() === "ok"
            root.saveText = ""
            if (ok)
                ownIndex.reload()
            root.saveDone(ok, ok ? id : "")
        }
    }
    FileView {
        id: ownIndex
        path: root.ownDir + "/index.json"
        printErrors: false
        onLoaded: root.readOwnIndex(text())
        onLoadFailed: root.readOwnIndex("")
    }
    Instantiator {
        model: root.ownIds
        delegate: FileView {
            required property string modelData
            path: root.ownDir + "/" + modelData + ".json"
            printErrors: false
            onLoaded: root.readOwnTheme(modelData, text())
            onLoadFailed: root.readOwnTheme(modelData, "")
        }
    }

    function readIndex(text) {
        let list = null
        try {
            list = text.length <= maxBytes ? JSON.parse(text) : null
        } catch (e) {
            list = null
        }
        if (!Array.isArray(list)) {
            console.warn("temas: themes/index.json ausente, grande demais ou inválido")
            list = []
        }
        const out = []
        for (const id of list) {
            if (typeof id === "string" && Palettes.THEME_NAME.test(id) && !out.includes(id) && out.length < maxThemes)
                out.push(id)
        }
        found = new Map()
        answeredIds = new Map()
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
            const f = new Map(found)
            f.set(id, theme)
            found = f
        }
        // Each id answers once (a delegate made again never counts twice)
        const a = new Map(answeredIds)
        a.set(id, true)
        answeredIds = a
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
