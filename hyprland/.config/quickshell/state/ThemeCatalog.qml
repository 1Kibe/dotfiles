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
    readonly property bool ready: indexRead && answered === ids.length
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
    // Read by a script (never a FileView: a FIFO or a link to an endless file
    // there would hold the catalog): every folder from HOME down a real
    // folder of the user's, never a link (cd -P each), and only regular
    // files of the user's, never links, of up to 64 KB, each sent as base64
    // on its own line; at most 5 s. The repo's themes never wait for them
    // (`ready` is the repo's); `ownRead` says they were read.
    readonly property int maxOwn: 24
    readonly property string home: Quickshell.env("HOME")
    readonly property string dataDir: Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"
    // Where the chain starts and its folders: HOME and the path under it, or
    // a data folder of its own outside HOME
    readonly property var ownChain: {
        const under = dataDir.startsWith(home + "/")
        const rel = (under ? dataDir.slice(home.length + 1) : "").split("/").filter(c => c !== "")
        const comps = rel.concat(["dotfiles", "themes"])
        const ok = home !== "" && comps.every(c => c !== "." && c !== ".." && !c.includes("\0"))
        return ok ? { start: under ? home : dataDir, comps: comps } : null
    }
    readonly property string ownDir: `${dataDir}/dotfiles/themes`
    property var ownIds: []
    property var ownFound: new Map()
    property bool ownRead: false
    function isOwnTheme(id) {
        return typeof id === "string" && Custom.OWN_ID.test(id)
    }

    // The chain's walk (shared): $1 start, $2 make missing folders (1 or 0),
    // $3 and $4 for the script after it, then the folders. Ends inside the
    // last one; exit 3: a folder missing (nothing to read)
    readonly property string chainScript:
        'start=$1; mk=$2; a=$3; b=$4; shift 4\n'
        + 'cd -P -- "$start" 2>/dev/null || exit 1\n'
        + '[ -O . ] || exit 1\n'
        + 'for c; do\n'
        + '  if [ -e "$c" ] || [ -L "$c" ]; then [ -d "$c" ] && [ ! -L "$c" ] && [ -O "$c" ] || exit 1\n'
        + '  elif [ "$mk" = 1 ]; then mkdir -m 700 -- "$c" || exit 1\n'
        + '  else exit 3; fi\n'
        + '  cd -P -- "$c" || exit 1\n'
        + 'done\n'
        // a regular file of the user's, not a link, up to 64 KB
        + 'okfile() { [ -f "$1" ] && [ ! -L "$1" ] && [ -O "$1" ] && [ "$(stat -c %s -- "$1")" -le 65536 ]; }\n'
    readonly property string readScript: chainScript
        + 'if okfile index.txt; then printf "@index "; head -c 65536 -- index.txt | base64 -w0; echo; fi\n'
        + 'n=0\n'
        + 'for f in seu-*.json; do\n'
        + '  okfile "$f" || continue\n'
        + '  n=$((n + 1)); [ "$n" -le 24 ] || break\n'
        + '  printf "%s " "${f%.json}"; head -c 65536 -- "$f" | base64 -w0; echo\n'
        + 'done\n'
    function readOwn() {
        if (ownChain === null) {
            ownIds = []
            ownFound = new Map()
            ownRead = true
            return
        }
        ownReader.command = ["timeout", "5", "sh", "-c", readScript, "sh", ownChain.start, "0", "", ""].concat(ownChain.comps)
        ownReader.running = true
    }
    // A base64 line to its text (UTF-8); null when it is not valid
    function decode64(line) {
        const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        if (!/^[A-Za-z0-9+/]*={0,2}$/.test(line) || line.length % 4 !== 0)
            return null
        let pct = ""
        for (let i = 0; i < line.length; i += 4) {
            const n = [0, 1, 2, 3].map(k => line[i + k] === "=" ? 0 : alphabet.indexOf(line[i + k]))
            const bits = (n[0] << 18) | (n[1] << 12) | (n[2] << 6) | n[3]
            const bytes = [(bits >> 16) & 255, (bits >> 8) & 255, bits & 255]
            const count = line[i + 2] === "=" ? 1 : line[i + 3] === "=" ? 2 : 3
            for (let k = 0; k < count; k++)
                pct += "%" + bytes[k].toString(16).padStart(2, "0")
        }
        try {
            return decodeURIComponent(pct)
        } catch (e) {
            return null
        }
    }
    function parseOwn(out) {
        let order = []
        const got = new Map()
        for (const line of out.split("\n")) {
            const sp = line.indexOf(" ")
            if (sp < 0)
                continue
            const key = line.slice(0, sp)
            const text = decode64(line.slice(sp + 1))
            if (text === null)
                continue
            if (key === "@index") {
                order = text.split("\n").filter(isOwnTheme)
                continue
            }
            if (!isOwnTheme(key))
                continue
            let theme = null
            try {
                const r = Palettes.validateTheme(JSON.parse(text))
                if (r.ok && r.theme.id === key)
                    theme = r.theme
            } catch (e) {
                theme = null
            }
            if (theme === null)
                console.warn("temas: tema próprio recusado: " + key)
            else
                got.set(key, theme)
        }
        // The index's order, then the others found
        const ids = order.filter(id => got.has(id))
        for (const id of got.keys())
            if (!ids.includes(id))
                ids.push(id)
        ownFound = got
        ownIds = ids.slice(0, maxOwn)
        ownRead = true
        // Saved with "Salvar e aplicar": picked now it is read back, unless
        // the screen locked meanwhile (then only saved)
        if (applyWhenRead !== "" && got.has(applyWhenRead)) {
            const id = applyWhenRead
            applyWhenRead = ""
            if (!LockState.locked && !LockState.wanted)
                SettingsStore.setMany({ theme: id, flavor: Palettes.flavors(got.get(id))[0].id })
        }
    }
    Process {
        id: ownReader
        stdout: StdioCollector {
            id: ownReaderOut
        }
        stderr: StdioCollector {}
        onExited: code => root.parseOwn(code === 0 || code === 3 ? ownReaderOut.text : "")
    }
    // (after the processes are built: a run asked before is lost)
    Component.onCompleted: Qt.callLater(readOwn)

    // Saving one (the editor's Salvar) or removing one (Excluir): the theme
    // checked again here; the chain walked (made 700 when missing); the file
    // and the index written 600 through a temporary file in the folder and
    // renamed over it (mv -T: never into a folder of that name); the index
    // made from the folder's own files. Never with the screen locked.
    // saveDone(ok, id) / removeDone(ok, id)
    signal saveDone(bool ok, string id)
    signal removeDone(bool ok, string id)
    property string saveText: ""
    // A saved theme to pick as soon as it is read back (the editor's
    // "Salvar e aplicar"): the store takes only a theme the catalog has
    property string applyWhenRead: ""
    readonly property bool busy: saver.running || ownReader.running
    // The index from the folder: the order asked ($b), then the other files
    readonly property string indexScript:
        'i=$(mktemp -- .indice.XXXXXX) || exit 1\n'
        + '{ printf "%s\\n" "$b" | while IFS= read -r x; do [ -n "$x" ] && okfile "$x.json" && echo "$x"; done\n'
        + '  for f in seu-*.json; do okfile "$f" || continue; printf "%s\\n" "$b" | grep -qxF -- "${f%.json}" || echo "${f%.json}"; done; } > "$i"\n'
        + 'chmod 600 -- "$i" && mv -fT -- "$i" index.txt || { rm -f -- "$i"; exit 1; }\n'
        + 'echo ok\n'
    readonly property string saveScript: 'umask 077\n' + chainScript
        + 'chmod 700 . || exit 1\n'
        + 't=$(mktemp -- .tema.XXXXXX) || exit 1\n'
        + 'cat > "$t" && chmod 600 -- "$t" && mv -fT -- "$t" "$a.json" || { rm -f -- "$t"; exit 1; }\n'
        + indexScript
    readonly property string removeScript: 'umask 077\n' + chainScript
        + '{ [ -f "$a.json" ] || [ -L "$a.json" ]; } && { rm -f -- "$a.json" || exit 1; }\n'
        + indexScript
    property string saverKind: ""
    property string saverId: ""
    function saveOwn(theme, andApply) {
        if (busy || !ownRead || ownChain === null || LockState.locked || LockState.wanted)
            return false
        const v = Palettes.validateTheme(theme)
        if (!v.ok || !isOwnTheme(v.theme.id))
            return false
        if (!ownIds.includes(v.theme.id) && ownIds.length >= maxOwn)
            return false
        const order = (ownIds.includes(v.theme.id) ? ownIds : ownIds.concat([v.theme.id])).join("\n")
        saveText = Custom.serialize(v.theme)
        applyWhenRead = andApply === true ? v.theme.id : ""
        saverKind = "save"
        saverId = v.theme.id
        saver.command = ["sh", "-c", saveScript, "sh", ownChain.start, "1", v.theme.id, order].concat(ownChain.comps)
        saver.stdinEnabled = true
        saver.running = true
        return true
    }
    function removeOwn(id) {
        if (busy || !ownRead || ownChain === null || !isOwnTheme(id) || !ownIds.includes(id)
                || LockState.locked || LockState.wanted)
            return false
        saveText = ""
        saverKind = "remove"
        saverId = id
        saver.command = ["sh", "-c", removeScript, "sh", ownChain.start, "0", id, ownIds.filter(x => x !== id).join("\n")]
                        .concat(ownChain.comps)
        saver.stdinEnabled = false
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
            if (running && root.saverKind === "save") {
                write(root.saveText)
                stdinEnabled = false
            }
        }
        onExited: code => {
            const ok = code === 0 && saverOut.text.trim() === "ok"
            const kind = root.saverKind, id = root.saverId
            root.saveText = ""
            root.saverKind = ""
            root.saverId = ""
            if (!ok)
                root.applyWhenRead = ""
            root.readOwn()
            if (kind === "save")
                root.saveDone(ok, ok ? id : "")
            else
                root.removeDone(ok, id)
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
