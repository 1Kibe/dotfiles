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
// The machine file is used only if it and its folder belong to the user, the
// folder is not a link and no one else can write to it, and the file has
// mode 600 (a file swapped by someone else is not trusted). A value that
// does not pass keeps the default; keys it does not use (unknown ones, from a
// newer version, or bad values) are written back untouched. A file that
// cannot be read or trusted is copied aside (settings.json.bad-<date>)
// before the first write, and nothing is written if that copy fails: nothing
// is ever lost on its own. Writes wait 300 ms, then go to a 600 temporary
// file in the same folder (700) and replace the file with `mv -T`, all as
// argument lists; the content never goes through a command line. The
// store's own writes are not read back as an outside change. Nothing is
// written before the first read is done.
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
    // Keys of the file it does not use, written back as they are
    property var extra: ({})
    // The file was there but could not be read or trusted: copied aside
    // before the first write
    property bool broken: false
    property bool defaultsRead: false
    property bool userRead: false
    property string uid: ""

    function own(obj, key) {
        return obj !== null && obj !== undefined && Object.prototype.hasOwnProperty.call(obj, key)
    }

    function spec(key) {
        return own(Schema.KEYS, key) ? Schema.KEYS[key] : null
    }

    function same(a, b) {
        return JSON.stringify(a) === JSON.stringify(b)
    }

    // undefined for anything that is not a key (also "__proto__")
    function get(key) {
        return own(values, key) ? values[key] : undefined
    }

    // false when the key is unknown, the value does not pass or the first
    // read is not done yet
    function set(key, value) {
        const s = spec(key)
        if (!s || !ready)
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
        if (!ready || !spec(key) || (!own(user, key) && !own(extra, key)))
            return false
        const next = Object.assign({}, user)
        delete next[key]
        apply(next, [key])
        return true
    }

    // Restaurar: every machine choice goes (the page asks first); keys this
    // version does not know stay
    function resetAll() {
        if (!ready)
            return false
        apply({}, Object.keys(user))
        return true
    }

    // Exportar: the current values that are not machine ones become the
    // repo's defaults (settings/defaults.json); the Ryan commits it later.
    // A path under the home goes as "~/..."; any other absolute path is not
    // exported (the repo's value stays) and is listed in `skipped`, for the
    // page to tell. Nothing before the first read.
    function exportDefaults() {
        if (!ready)
            return { ok: false, skipped: [] }
        const out = {}
        const skipped = []
        for (const key of Object.keys(Schema.KEYS)) {
            const s = Schema.KEYS[key]
            if (s.machine)
                continue
            let v = values[key]
            if (s.type === "path") {
                if (v === home)
                    v = "~"
                else if (v.startsWith(home + "/"))
                    v = "~" + v.slice(home.length)
                else if (v !== "~" && !v.startsWith("~/")) {
                    skipped.push(key)
                    v = defaults[key]
                }
            }
            out[key] = v
        }
        defaultsView.setText(JSON.stringify(out, null, 2) + "\n")
        return { ok: true, skipped: skipped }
    }

    // New machine choices: values, the signal for each changed key, then the
    // file (300 ms later). A key set or reset here leaves `extra`.
    function apply(next, keys) {
        const left = Object.assign(Object.create(null), extra)
        for (const k of keys)
            delete left[k]
        extra = left
        user = next
        rebuild()
        for (const k of keys)
            changed(k)
        saveTimer.restart()
    }

    function rebuild() {
        const v = {}
        for (const key of Object.keys(Schema.KEYS))
            v[key] = own(user, key) ? user[key] : defaults[key]
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
            const r = file && typeof file === "object" && own(file, key)
                      ? Validate.validate(s, file[key], home) : { ok: false }
            d[key] = r.ok ? r.value : s.def
        }
        defaults = d
        defaultsRead = true
        rebuild()
    }

    // The machine's choices; what it does not use goes to `extra`, and a file
    // that cannot be read keeps the defaults with a notice (once) and is
    // copied aside before the first write
    function readUser(text) {
        let file = null
        try {
            file = JSON.parse(text)
        } catch (e) {
            file = null
        }
        const u = {}
        const x = Object.create(null)
        if (!file || typeof file !== "object" || Array.isArray(file)) {
            broken = true
            if (readState !== "broken")
                notice("Não deu para ler suas configurações; usando os padrões")
        } else {
            broken = false
            for (const key of Object.keys(file)) {
                const s = spec(key)
                const r = s ? Validate.validate(s, file[key], home) : { ok: false }
                if (!r.ok)
                    x[key] = file[key]
                else if (!same(r.value, defaults[key]))
                    u[key] = r.value
            }
        }
        user = u
        extra = x
    }

    property string lastNotice: ""
    function notice(text) {
        if (lastNotice === text)
            return
        lastNotice = text
        loadError = text
    }

    // "uid rawmode" of stat (%u %f: the raw mode in hex, type bits
    // included, the same in any language; no link followed) → whether it is
    // the user's, of that type ("dir" or "file"), with no write for group or
    // others; "file" also needs mode 600
    function statOk(out, type) {
        const m = out.trim().match(/^(\d+) ([0-9a-fA-F]+)$/)
        if (m === null || m[1] !== uid)
            return false
        const mode = parseInt(m[2], 16)
        const kind = mode & 0o170000
        const perm = mode & 0o777
        if (type === "dir")
            return kind === 0o040000 && (perm & 0o022) === 0
        return kind === 0o100000 && perm === 0o600
    }

    // Folder, then file: the file's content is used only when both pass and
    // the file has mode 600. The stats and the read run side by side;
    // tryRead() decides once both are in.
    property string userState: "pending"   // "pending" | "missing" | "bad" | "ok"
    // What the last read found: "", "missing", "bad", "broken" or "ok"
    property string readState: ""
    property bool userLoading: true

    function checkUser() {
        userState = "pending"
        run(["stat", "-c", "%u %f", "--", userDir], (code, out) => {
            if (code !== 0) {
                userState = "missing"
                return tryRead()
            }
            if (!statOk(out, "dir")) {
                userState = "bad"
                return tryRead()
            }
            run(["stat", "-c", "%u %f", "--", userFile], (code2, out2) => {
                if (code2 !== 0)
                    userState = "missing"
                else
                    userState = statOk(out2, "file") ? "ok" : "bad"
                tryRead()
            })
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
            extra = Object.create(null)
            broken = false
        } else if (userState === "bad") {
            // Once per change of state: reading the same untrusted file again
            // (a folder event) does not cover a newer notice
            if (readState !== "bad")
                notice("Suas configurações têm dono ou permissão errados; usando os padrões")
            user = {}
            extra = Object.create(null)
            broken = true
        } else {
            const text = userView.text()
            // The store's own write coming back: nothing new
            if (expected !== "" && text === expected)
                expected = ""
            else
                readUser(text)
        }
        readState = userState === "ok" ? (broken ? "broken" : "ok") : userState
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
    // tryRead() once the folder, the owner and the mode are checked
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
        // Keys it does not use first, the choices over them, sorted
        const all = Object.assign(Object.create(null), extra, user)
        const out = Object.create(null)
        for (const k of Object.keys(all).sort())
            out[k] = all[k]
        const content = JSON.stringify(out, null, 2) + "\n"
        // The folder (700, the user's, not a link), the old file copied aside
        // if it was not usable, a fresh empty 600 temporary, the content into
        // it, then the rename
        run(["mkdir", "-p", "-m", "700", "--", userDir], code => {
            if (code !== 0)
                return failWrite()
            run(["stat", "-c", "%u %f", "--", userDir], (code2, out2) => {
                const m = out2.trim().match(/^(\d+) ([0-9a-fA-F]+)$/)
                // The user's own folder, not a link (the mode is fixed next)
                if (code2 !== 0 || !m || m[1] !== uid || (parseInt(m[2], 16) & 0o170000) !== 0o040000)
                    return failWrite()
                run(["chmod", "700", "--", userDir], code3 => {
                    if (code3 !== 0)
                        return failWrite()
                    backupIfBroken(() => {
                        run(["install", "-m", "600", "-T", "/dev/null", tmpFile], code4 => {
                            if (code4 !== 0)
                                return failWrite()
                            root.pending = content
                            tmpView.setText(content)
                        })
                    })
                })
            })
        })
    }

    // A file that could not be read or trusted is kept as
    // settings.json.bad-<date>; if that copy fails, nothing is written. Only
    // a regular file is copied (stat follows no link): a link, a FIFO or a
    // device is never read, and `mv -T` then replaces only that entry of the
    // folder, leaving whatever it pointed to untouched
    function backupIfBroken(next) {
        if (!broken)
            return next()
        run(["stat", "-c", "%u %f", "--", userFile], (code, out) => {
            const m = out.trim().match(/^(\d+) ([0-9a-fA-F]+)$/)
            if (code !== 0 || !m || (parseInt(m[2], 16) & 0o170000) !== 0o100000) {
                broken = false
                return next()
            }
            const copy = `${userFile}.bad-${Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss")}`
            run(["cp", "-P", "-p", "-T", "--", userFile, copy], code2 => {
                if (code2 !== 0)
                    return failWrite()
                broken = false
                notice(`Suas configurações antigas foram guardadas em ${copy.split("/").pop()}`)
                next()
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
                if (code !== 0)
                    return root.failWrite()
                root.expected = root.pending
                root.writeDone(true)
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

    // A command that cannot even start (a missing binary) never sends
    // `exited`: it ends with -1, so a chain never waits forever
    component Job: Process {
        property var done: null
        property bool finished: false
        stdout: StdioCollector {
            id: out
        }
        function finish(code, text) {
            if (finished)
                return
            finished = true
            if (done)
                done(code, text)
            destroy()
        }
        onExited: code => finish(code, out.text)
        onRunningChanged: {
            if (!running && !finished)
                Qt.callLater(() => finish(-1, ""))
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
