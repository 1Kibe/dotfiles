pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/schema.js" as Schema
import "../settings/validate.js" as Validate

// The settings (Configurações): the defaults of the repo
// (settings/defaults.json, over the schema's own) and this machine's choices
// (~/.config/dotfiles/settings.json, only the keys that differ from the
// defaults), each checked against settings/schema.js. Modules bind to
// `values`, a new object at every change.
//
// The machine file is read only if it belongs to the user and has mode 600
// (a file swapped by someone else is not trusted); a value that does not
// pass keeps the default, and an unknown key is ignored. Nothing is ever
// deleted on its own. Writes wait 300 ms, then go to a 600 temporary file in
// the same folder (700) and replace the file with `mv -T`, all as argument
// lists; the content never goes through a command line. The store's own
// writes are not read back as an outside change.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string userDir: `${home}/.config/dotfiles`
    readonly property string userFile: `${userDir}/settings.json`
    readonly property string tmpFile: `${userDir}/.settings.json.new`
    readonly property string defaultsFile: Quickshell.shellPath("settings/defaults.json")

    // key -> value, for binding; replaced as a whole on every change
    property var values: ({})
    property bool ready: false
    // A short notice for the screen (never the file's content); "" when fine
    property string loadError: ""

    signal changed(string key)

    // The repo's defaults (checked) and the machine's choices (checked, only
    // keys that differ)
    property var defaults: ({})
    property var user: ({})
    property bool defaultsRead: false
    property bool userRead: false
    property string uid: ""

    function spec(key) {
        return Object.prototype.hasOwnProperty.call(Schema.KEYS, key) ? Schema.KEYS[key] : null
    }

    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b)
    }

    function get(key) {
        return values[key]
    }

    // false when the key is unknown or the value does not pass
    function set(key, value) {
        const s = spec(key)
        if (!s)
            return false
        const r = Validate.validate(s, value, home)
        if (!r.ok)
            return false
        const next = Object.assign({}, user)
        if (same(r.value, defaults[key]))
            delete next[key]
        else
            next[key] = r.value
        apply(next, [key])
        return true
    }

    function reset(key) {
        if (!spec(key) || !Object.prototype.hasOwnProperty.call(user, key))
            return
        const next = Object.assign({}, user)
        delete next[key]
        apply(next, [key])
    }

    // Restaurar: every machine choice goes (the page asks first)
    function resetAll() {
        apply({}, Object.keys(user))
    }

    // Exportar: the current values that are not machine ones become the
    // repo's defaults (settings/defaults.json); the Ryan commits it later
    function exportDefaults() {
        const out = {}
        for (const key of Object.keys(Schema.KEYS)) {
            if (!Schema.KEYS[key].machine)
                out[key] = values[key]
        }
        defaultsView.setText(JSON.stringify(out, null, 2) + "\n")
        return true
    }

    // New machine choices: values, the signal for each changed key, then the
    // file (300 ms later)
    function apply(next, keys) {
        user = next
        rebuild()
        for (const k of keys)
            changed(k)
        saveTimer.restart()
    }

    function rebuild() {
        const v = {}
        for (const key of Object.keys(Schema.KEYS))
            v[key] = Object.prototype.hasOwnProperty.call(user, key) ? user[key] : defaults[key]
        values = v
        ready = defaultsRead && userRead
    }

    // ── Reading ──

    // The schema's defaults, replaced by the valid ones of defaults.json
    function readDefaults(text) {
        let file = {}
        try {
            file = text.trim() === "" ? {} : JSON.parse(text)
        } catch (e) {
            file = {}
        }
        const d = {}
        for (const key of Object.keys(Schema.KEYS)) {
            const s = Schema.KEYS[key]
            const r = file && typeof file === "object" && Object.prototype.hasOwnProperty.call(file, key)
                      ? Validate.validate(s, file[key], home) : { ok: false }
            d[key] = r.ok ? r.value : s.def
        }
        defaults = d
        defaultsRead = true
        rebuild()
    }

    // The machine's choices: unknown keys and bad values are left out, and a
    // file that cannot be read keeps the defaults with a notice (once)
    function readUser(text) {
        let file = null
        try {
            file = JSON.parse(text)
        } catch (e) {
            file = null
        }
        const u = {}
        if (!file || typeof file !== "object" || Array.isArray(file)) {
            notice("Não deu para ler suas configurações; usando os padrões")
        } else {
            for (const key of Object.keys(file)) {
                const s = spec(key)
                if (!s)
                    continue
                const r = Validate.validate(s, file[key], home)
                if (r.ok && !same(r.value, defaults[key]))
                    u[key] = r.value
            }
        }
        user = u
    }

    property string lastNotice: ""
    function notice(text) {
        if (lastNotice === text)
            return
        lastNotice = text
        loadError = text
    }

    // Owner and mode first: the file's content is used only when it is the
    // user's own file with mode 600. The stat and the read run side by side;
    // tryRead() decides once both are in.
    property string userState: "pending"   // "pending" | "missing" | "bad" | "ok"
    property bool userLoading: true

    function checkUser() {
        userState = "pending"
        run(["stat", "-c", "%u %a", "--", userFile], (code, out) => {
            if (code !== 0) {
                userState = "missing"
            } else {
                const parts = out.trim().split(" ")
                userState = parts[0] === uid && parts[1] === "600" ? "ok" : "bad"
            }
            tryRead()
        })
    }

    function tryRead() {
        if (userState === "pending" || userLoading)
            return
        // An outside change after the first read: the keys that changed are
        // announced, like a change made here (the first read is not)
        const before = ready ? values : null
        if (userState === "missing") {
            user = {}
        } else if (userState === "bad") {
            notice("Suas configurações têm dono ou permissão errados; usando os padrões")
            user = {}
        } else {
            const text = userView.text()
            // The store's own write coming back: nothing new
            if (expected !== "" && text === expected)
                expected = ""
            else
                readUser(text)
        }
        userRead = true
        rebuild()
        if (before) {
            for (const key of Object.keys(Schema.KEYS)) {
                if (!same(before[key], values[key]))
                    changed(key)
            }
        }
    }

    Component.onCompleted: {
        run(["id", "-u"], (code, out) => {
            uid = out.trim()
            checkUser()
        })
    }

    FileView {
        id: defaultsView
        path: root.defaultsFile
        watchChanges: true
        printErrors: false
        onLoaded: root.readDefaults(text())
        onLoadFailed: root.readDefaults("")
        onFileChanged: reload()
        // Exportar: only after the defaults are in, never half written
        atomicWrites: true
    }

    // Read on its own (and again when it changes), but only used by
    // tryRead() once the owner and the mode are checked
    FileView {
        id: userView
        path: root.userFile
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.userLoading = false
            root.tryRead()
        }
        onLoadFailed: {
            root.userLoading = false
            root.tryRead()
        }
        onFileChanged: {
            root.userLoading = true
            reload()
            root.checkUser()
        }
    }

    // ── Writing ──

    // The text of the last write, to recognize it when the file changes
    property string expected: ""
    property bool writing: false
    property bool dirty: false

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root.save()
    }

    function save() {
        if (writing) {
            dirty = true
            return
        }
        writing = true
        dirty = false
        const keys = Object.keys(root.user).sort()
        const out = {}
        for (const k of keys)
            out[k] = root.user[k]
        const content = JSON.stringify(out, null, 2) + "\n"
        // The folder (700), a fresh empty 600 temporary in it, the content
        // into it, then the rename
        run(["mkdir", "-p", "-m", "700", "--", userDir], code => {
            if (code !== 0)
                return failWrite()
            run(["chmod", "700", "--", userDir], () => {
                run(["install", "-m", "600", "-T", "/dev/null", tmpFile], code2 => {
                    if (code2 !== 0)
                        return failWrite()
                    root.pending = content
                    tmpView.setText(content)
                })
            })
        })
    }

    property string pending: ""

    FileView {
        id: tmpView
        path: root.tmpFile
        preload: false
        printErrors: false
        // In place: the empty file made with mode 600 keeps it
        atomicWrites: false
        onSaved: {
            root.run(["mv", "-T", "--", root.tmpFile, root.userFile], code => {
                if (code === 0)
                    root.expected = root.pending
                root.writeDone(code === 0)
            })
        }
        onSaveFailed: root.failWrite()
    }

    function failWrite() {
        notice("Não deu para salvar suas configurações")
        writeDone(false)
    }

    function writeDone(ok) {
        writing = false
        if (dirty)
            saveTimer.restart()
    }

    // ── Commands (argument lists only) ──

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
}
