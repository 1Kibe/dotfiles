pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/apps.js" as Apps
import "../settings/serialize.js" as Serialize

// Configurações → Apps padrão and Iniciar com o sistema, outside the page.
//
// The apps: a scan of the .desktop files directly in the applications
// folders (the user's first, then $XDG_DATA_DIRS and Flatpak's exports):
// regular files only (no link is followed), under 64 KB, read by a fixed awk
// that keeps only the [Desktop Entry] group and only Name, Type, Hidden,
// NoDisplay, MimeType, Categories, Terminal and Icon (settings/apps.js
// checks each one). Exec, TryExec and Path are never read.
//
// The defaults: the page shows what `xdg-mime query default` says, not what
// was saved. A choice goes to the system only from the page (apply()): the
// folders are scanned again, the app must still be there and serve that row,
// and `xdg-mime default` gets its id and the row's types it declares. Never
// at start, from a change of the settings file or from Restaurar, and never
// with the session locked.
//
// The terminal and the file manager of the keybinds (Super+Enter, Super+E)
// and the apps started at login are written as data only (ids) to
// ~/.config/hypr/dotfiles_apps.lua and dotfiles_autostart.lua (out of git),
// read by hypr/modules/actions.lua and autostart.lua, which check every id
// again and open it with a fixed launcher.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"}/hypr`
    property var apps: []
    property bool scanned: false
    // key -> the system's default id ("" when none or not known)
    property var current: ({})
    property string message: ""
    property bool busy: false
    signal failed(string message)

    function locked() {
        return LockState.locked || LockState.wanted
    }
    function fail(text) {
        message = text
        failed(text)
    }

    // ── The scan ──
    readonly property var folders: {
        const dataHome = Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
        const dirs = (Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share").split(":")
                     .filter(d => d.startsWith("/") && !d.split("/").includes(".."))
        return [`${dataHome}/applications`].concat(dirs.map(d => `${d}/applications`),
               [`${dataHome}/flatpak/exports/share/applications`, "/var/lib/flatpak/exports/share/applications"])
    }
    readonly property string awk:
        'FNR == 1 { if (id != "") emit(); id = FILENAME; sub(/^.*\\//, "", id); grp = ""; split("", v) }\n'
        + '/^\\[/ { grp = $0; sub(/[ \\t\\r]+$/, "", grp); next }\n'
        + 'grp == "[Desktop Entry]" && /^(Name|Type|Hidden|NoDisplay|MimeType|Categories|Terminal|Icon)=/ {\n'
        + '  k = substr($0, 1, index($0, "=") - 1)\n'
        + '  if (!(k in v)) { val = substr($0, index($0, "=") + 1); gsub(/[\\t\\r]/, " ", val); v[k] = val }\n'
        + '}\n'
        + 'END { if (id != "") emit() }\n'
        + 'function emit() { printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n", id, v["Name"], v["Type"], v["Hidden"], '
        + 'v["NoDisplay"], v["MimeType"], v["Categories"], v["Terminal"], v["Icon"] }\n'
    function scanCommand() {
        return ["find"].concat(folders, ["-maxdepth", "1", "-type", "f", "-name", "*.desktop", "-size", "-65k",
                                         "-exec", "awk", awk, "{}", "+"])
    }
    function scan(done) {
        run(scanCommand(), (code, out) => {
            // find exits non-zero when a folder is missing; its output still counts
            root.apps = Apps.parseScan(out)
            root.scanned = true
            if (done)
                done()
        })
    }
    function refresh() {
        scan(() => root.queryAll())
    }
    Component.onCompleted: refresh()

    // What the system says now, row by row
    function queryAll() {
        for (const k of Apps.KEYS) {
            const type = Apps.queryType(k.key)
            if (type === "")
                continue
            run(["xdg-mime", "query", "default", type], (code, out) => {
                const next = Object.assign({}, root.current)
                next[k.key] = code === 0 ? Apps.queryResult(out) : ""
                root.current = next
            })
        }
    }
    function find(id) {
        return apps.find(a => a.id === id) || null
    }
    // Rows that show: the fixed ones, and the optional ones some app opens
    function rows() {
        return Apps.KEYS.filter(k => !Apps.OPTIONAL.includes(k.key) || Apps.candidates(k.key, apps).length > 0)
    }

    // ── A choice from the page ──
    function apply(key, id) {
        if (locked()) {
            fail("Com a sessão travada, nada muda")
            return false
        }
        if (busy || !Apps.spec(key))
            return false
        const terminal = key === "appTerminal" || key === "appFiles"
        // Terminal and Arquivos may go back to the shell's own (Kitty, Thunar)
        if (terminal && id === "") {
            SettingsStore.set(key, "")
            return true
        }
        busy = true
        message = ""
        // Scanned again: the app must still be there and serve the row
        scan(() => {
            const a = root.find(id)
            if (a === null || !Apps.serves(key, a) || root.locked()) {
                root.busy = false
                root.fail("Esse app não está mais disponível")
                return
            }
            const batches = Apps.xdgArgs(key, a)
            root.runAll(batches, ok => {
                root.busy = false
                if (!ok) {
                    root.fail("Não deu para trocar o app padrão")
                    root.queryAll()
                    return
                }
                SettingsStore.set(key, a.id)
                root.queryAll()
            })
        })
        return true
    }
    function runAll(batches, done) {
        if (batches.length === 0)
            return done(true)
        run(batches[0], code => {
            if (code !== 0)
                return done(false)
            root.runAll(batches.slice(1), done)
        })
    }

    // ── Iniciar com o sistema ──
    readonly property var startable: Apps.startable(apps)
    function addStart(id) {
        const list = SettingsStore.get("autostartApps") || []
        const a = find(id)
        if (locked() || a === null || !startable.some(x => x.id === id) || list.includes(id) || list.length >= 16)
            return false
        return SettingsStore.set("autostartApps", list.concat([id]))
    }
    function removeStart(id) {
        const list = SettingsStore.get("autostartApps") || []
        if (locked() || !list.includes(id))
            return false
        return SettingsStore.set("autostartApps", list.filter(x => x !== id))
    }

    // ── The data files ──
    // Written from the saved values (only ids), only when the text changes,
    // the old one kept as .prev. A new dotfiles_apps.lua reloads Hyprland (the
    // keybinds read it when they load), never with the session locked; the
    // autostart one waits for the next login.
    readonly property string appsText: SettingsStore.ready
        ? Apps.appsLua(SettingsStore.get("appTerminal"), SettingsStore.get("appFiles"), Serialize.luaValue) : ""
    readonly property string startText: SettingsStore.ready
        ? Apps.autostartLua(SettingsStore.get("autostartArtcraft") !== false, SettingsStore.get("autostartApps"),
                            Serialize.luaValue) : ""
    onAppsTextChanged: appsTimer.restart()
    onStartTextChanged: startTimer.restart()
    readonly property bool sessionLocked: locked()
    onSessionLockedChanged: if (!sessionLocked) appsTimer.restart()
    Timer {
        id: appsTimer
        interval: 500
        onTriggered: root.writeData(appsView, appsPrev, root.appsText, true)
    }
    Timer {
        id: startTimer
        interval: 500
        onTriggered: root.writeData(startView, startPrev, root.startText, false)
    }
    function writeData(view, prev, text, reload) {
        if (text === "" || !view.ready || view.text() === text)
            return
        if (reload && locked())
            return
        view.wanted = text
        view.reloadAfter = reload
        if (view.text() !== "")
            prev.setText(view.text())
        else
            view.setText(text)
    }
    component DataFile: FileView {
        property bool ready: false
        property string wanted: ""
        property bool reloadAfter: false
        printErrors: false
        atomicWrites: true
        onLoaded: ready = true
        onLoadFailed: ready = true
    }
    DataFile {
        id: appsView
        path: `${root.hyprDir}/dotfiles_apps.lua`
        onReadyChanged: appsTimer.restart()
        onSaved: if (reloadAfter && !root.locked()) Quickshell.execDetached(["hyprctl", "reload"])
        onSaveFailed: root.fail("Não deu para gravar o terminal e os arquivos dos atalhos")
    }
    FileView {
        id: appsPrev
        path: `${root.hyprDir}/dotfiles_apps.lua.prev`
        printErrors: false
        atomicWrites: true
        onSaved: appsView.setText(appsView.wanted)
        onSaveFailed: root.fail("Não deu para gravar o terminal e os arquivos dos atalhos")
    }
    DataFile {
        id: startView
        path: `${root.hyprDir}/dotfiles_autostart.lua`
        onReadyChanged: startTimer.restart()
        onSaveFailed: root.fail("Não deu para gravar os apps que iniciam com o sistema")
    }
    FileView {
        id: startPrev
        path: `${root.hyprDir}/dotfiles_autostart.lua.prev`
        printErrors: false
        atomicWrites: true
        onSaved: startView.setText(startView.wanted)
        onSaveFailed: root.fail("Não deu para gravar os apps que iniciam com o sistema")
    }

    // ── Commands (argument lists only) ──
    component Job: Process {
        id: job
        property var done: null
        property bool finished: false
        property bool gotExit: false
        property bool gotOutput: false
        property int exitCode: -1
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                job.gotOutput = true
                job.settle()
            }
        }
        function settle() {
            if (gotExit && gotOutput)
                finish(exitCode, out.text)
        }
        function finish(code, text) {
            if (finished)
                return
            finished = true
            if (done)
                done(code, text)
            destroy()
        }
        onExited: code => {
            exitCode = code
            gotExit = true
            settle()
            if (!finished)
                outputWait.start()
        }
        onRunningChanged: {
            if (!running && !finished)
                Qt.callLater(() => {
                    if (!job.gotExit)
                        job.finish(-1, "")
                })
        }
        property Timer outputWait: Timer {
            interval: 1000
            onTriggered: job.finish(job.exitCode, out.text)
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
