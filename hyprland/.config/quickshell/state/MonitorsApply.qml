pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../settings/monitors.js" as Monitors
import "../settings/serialize.js" as Serialize

// Configurações → Monitores, outside the page: the screens as Hyprland has
// them (hyprctl -j monitors all, read again when screens come and go), and
// trying an arrangement before keeping it.
//
// preview() first arms the way back, outside the shell: a systemd timer
// that runs `hyprctl reload` in 15 s (the file on disk comes back even if
// the shell has died). Only then the arrangement is applied with `hyprctl
// eval`, the generated text as one argument. A second preview applies over
// it without a new timer or more time. A timer left from before (stuck,
// failed) refuses the preview: nothing is removed blindly.
//
// keep() writes exactly the text that was tried (its hash checked) to
// ~/.config/hypr/dotfiles_monitors.lua, the file before kept as .prev, and
// only while the preview still holds: once the timer fired (or anything
// else reloaded Hyprland) the preview is over and nothing is written. Then
// a reload and, a second later, what Hyprland says compared with what was
// asked: a screen that differs is local.lua's doing (it loads last); no
// screen on brings .prev back.
//
// The page edits a draft (a copy of the screens): nothing reaches Hyprland
// until applyDraft(). With no change in it, the draft follows the screens.
// local.lua is read (text only) to tell the page when it has monitor lines.
//
// Nothing here runs while the session is locked. Every command is an
// argument list; names and numbers come only from settings/monitors.js.
Singleton {
    id: root

    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr`
    readonly property string file: `${hyprDir}/dotfiles_monitors.lua`
    readonly property string unit: "hypr-monitores-voltar"
    readonly property int seconds: 15

    // The screens now ([] until read)
    property var screens: []
    // What the page shows: the last refusal or failure, and a warning
    property string message: ""
    property string warning: ""
    signal failed(string message)

    // The preview: on while the way back is armed and has not fired
    property bool pending: false
    property double deadline: 0
    property string previewText: ""
    property string previewHash: ""
    property var asked: []
    property bool busy: false
    // A reload of ours (keep, revert): not the end of a preview by itself
    property bool ownReload: false

    // Identify: a big number on each screen for a moment
    property bool identifying: false
    function identify() {
        identifying = true
        identifyTimer.restart()
    }
    Timer {
        id: identifyTimer
        interval: 2000
        onTriggered: root.identifying = false
    }

    function fail(text) {
        message = text
        failed(text)
    }

    function refresh() {
        readJob.running = true
    }
    Process {
        id: readJob
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try {
                    list = JSON.parse(text)
                } catch (e) {
                    list = []
                }
                root.screens = Monitors.fromHyprctl(list)
            }
        }
    }
    // Screens coming and going: one read a second after the last change
    Connections {
        target: Quickshell
        function onScreensChanged() { readSoon.restart() }
    }
    Timer {
        id: readSoon
        interval: 1000
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()

    // A reload while previewing ends it (the timer's, or anyone's): the
    // file is what holds now
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "configreloaded")
                return
            if (root.ownReload) {
                root.ownReload = false
                return
            }
            if (root.pending)
                root.endPreview("A prévia acabou: voltou ao arranjo salvo")
            readSoon.restart()
        }
    }
    function endPreview(text) {
        pending = false
        previewText = ""
        previewHash = ""
        deadline = 0
        expiry.stop()
        if (text)
            message = text
    }
    // The timer's own end, also when the reload event is missed
    Timer {
        id: expiry
        onTriggered: {
            if (root.pending)
                root.endPreview("A prévia acabou: voltou ao arranjo salvo")
            root.refresh()
        }
    }
    readonly property int left: pending ? Math.max(0, Math.ceil((deadline - clock.now) / 1000)) : 0
    QtObject {
        id: clock
        property double now: Date.now()
    }
    Timer {
        interval: 250
        repeat: true
        running: root.pending
        onTriggered: clock.now = Date.now()
    }

    function locked() {
        return LockState.locked || LockState.wanted
    }

    // ── Try ──
    function preview(list) {
        if (locked()) {
            fail("Com a sessão travada, as telas não mudam")
            return false
        }
        if (busy)
            return false
        // One preview at a time: not over the keyboard's
        if (!pending && KeyboardLayout.pending) {
            fail("Espere a prévia do teclado acabar")
            return false
        }
        const result = Monitors.generate(list, Monitors.modesOf(screens), Serialize.luaValue)
        if (!result.ok) {
            fail(result.error)
            return false
        }
        message = ""
        warning = ""
        if (pending) {
            // Over the running preview: same timer, no more time
            previewText = result.text
            previewHash = Qt.md5(result.text)
            asked = list
            apply(result.text)
            return true
        }
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
        if (!/^[A-Za-z0-9_]{1,128}$/.test(sig)) {
            fail("Não achei a sessão do Hyprland")
            return false
        }
        busy = true
        // A way back left from before: refuse, remove nothing
        run(["systemctl", "--user", "show", "-p", "LoadState", "--value", `${unit}.timer`, `${unit}.service`],
            (code, out) => {
            if (code !== 0 || out.split("\n").filter(l => l.trim() !== "").some(l => l.trim() !== "not-found")) {
                root.busy = false
                root.fail("Uma volta de antes ainda está armada: espere ela acabar")
                return
            }
            // AccuracySec: a transient timer may otherwise fire up to a
            // minute late (systemd's default accuracy), long after the strip
            // is gone
            run(["systemd-run", "--user", "--collect", `--unit=${root.unit}`, `--on-active=${root.seconds}s`,
                 "--timer-property=AccuracySec=100ms", `--setenv=HYPRLAND_INSTANCE_SIGNATURE=${sig}`,
                 "hyprctl", "reload"], code2 => {
                root.busy = false
                if (code2 !== 0) {
                    root.fail("Não deu para armar a volta: nada foi aplicado")
                    return
                }
                root.pending = true
                root.deadline = Date.now() + root.seconds * 1000
                expiry.interval = root.seconds * 1000 + 1500
                expiry.restart()
                root.previewText = result.text
                root.previewHash = Qt.md5(result.text)
                root.asked = list
                root.apply(result.text)
            })
        })
        return true
    }
    function apply(text) {
        // Without the header comment: hyprctl reads an argument that starts
        // with "--" as its own option (and the code never runs)
        const code = text.replace(/^--[^\n]*\n/, "")
        if (!code.startsWith("hl.monitor(")) {
            fail("O arranjo gerado não começa como devia")
            revert()
            return
        }
        run(["hyprctl", "eval", code], code => {
            if (code !== 0) {
                root.fail("O Hyprland não aceitou o arranjo")
                root.revert()
            } else {
                readSoon.restart()
            }
        })
    }

    // ── Keep ──
    function keep() {
        if (locked() || !pending || Date.now() >= deadline || busy)
            return false
        const text = previewText
        if (text === "" || Qt.md5(text) !== previewHash) {
            fail("A prévia mudou: nada foi gravado")
            return false
        }
        busy = true
        run(["systemctl", "--user", "stop", `${unit}.timer`], code => {
            // The timer may have fired meanwhile: then the preview is over
            if (code !== 0 || !root.pending || Date.now() >= root.deadline) {
                root.busy = false
                root.fail("A prévia acabou antes de manter: nada foi gravado")
                return
            }
            root.keptAsked = root.asked
            root.endPreview("")
            root.write(text)
        })
        return true
    }
    property var keptAsked: []
    // Bringing .prev back: once only (no screen after it either: stop there)
    property bool restoring: false
    property string prevText: ""
    property bool fileRead: false
    property string writing: ""
    function write(text) {
        prevText = fileRead ? fileView.text() : ""
        if (prevText === text) {
            busy = false
            return
        }
        // The write follows a link: the file and its .prev must be missing or
        // plain files, else nothing is written
        plainOrMissing([file, `${file}.prev`], ok => {
            if (!ok) {
                root.busy = false
                root.fail("O arquivo das telas é um link ou não pôde ser conferido: nada foi gravado")
                return
            }
            root.writing = text
            if (root.prevText !== "")
                prevView.setText(root.prevText)
            else
                fileView.setText(text)
        })
    }
    // Every path a plain file or missing (settings/serialize.js writeCheck);
    // a link, an error or no answer: no
    function plainOrMissing(paths, done) {
        if (paths.length === 0)
            return done(true)
        let check = null
        try {
            check = Serialize.writeCheck(paths[0])
        } catch (e) {
            return done(false)
        }
        run(check, code => {
            if (!Serialize.mayWrite(code))
                return done(false)
            root.plainOrMissing(paths.slice(1), done)
        })
    }
    FileView {
        id: prevView
        path: `${root.file}.prev`
        printErrors: false
        atomicWrites: true
        onSaved: fileView.setText(root.writing)
        onSaveFailed: {
            root.busy = false
            root.fail("Não deu para guardar o arranjo anterior: nada foi gravado")
        }
    }
    FileView {
        id: fileView
        path: root.file
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.fileRead = true
        onLoadFailed: root.fileRead = true
        onSaved: {
            root.ownReload = true
            root.run(["hyprctl", "reload"], () => checkTimer.restart())
        }
        onSaveFailed: {
            root.busy = false
            root.fail("Não deu para gravar o arranjo")
        }
    }

    // A second after the reload: what Hyprland says against what was asked
    Timer {
        id: checkTimer
        interval: 1000
        onTriggered: root.run(["hyprctl", "-j", "monitors", "all"], (code, out) => {
            let list = []
            try {
                list = JSON.parse(out)
            } catch (e) {
                list = []
            }
            root.screens = Monitors.fromHyprctl(list)
            root.check(root.screens)
        })
    }
    function check(now) {
        busy = false
        if (restoring) {
            restoring = false
            return
        }
        if (!now.some(s => s.enabled && !s.mirror)) {
            // No screen: the file before comes back (hyprland.lua turns the
            // known screens on by itself in the meantime)
            if (prevText !== "") {
                restoring = true
                writing = prevText
                const back = prevText
                plainOrMissing([file], ok => {
                    if (ok)
                        fileView.setText(back)
                    else
                        root.restoring = false
                })
            }
            fail("Sem tela depois de gravar: voltou ao arranjo anterior")
            return
        }
        const differ = keptAsked.filter(a => {
            const s = now.find(x => x.name === a.name)
            if (!s)
                return false
            if (!a.enabled)
                return s.enabled
            if (a.mirror)
                return s.mirror !== a.mirror
            return !s.enabled || s.x !== a.x || s.y !== a.y || Math.abs(s.scale - a.scale) > 0.01
                   || s.transform !== a.transform || !s.mode || s.mode.w !== a.mode.w || s.mode.h !== a.mode.h
        }).map(a => a.name)
        warning = differ.length > 0 ? `O local.lua está mandando nesta tela: ${differ.join(", ")}` : ""
        resetDraft()
    }
    // ── Back ──
    function revert() {
        if (!pending)
            return
        endPreview("Voltou ao arranjo salvo")
        run(["systemctl", "--user", "stop", `${unit}.timer`], () => {
            root.ownReload = true
            root.run(["hyprctl", "reload"], () => readSoon.restart())
        })
    }

    // ── The page's draft ──
    property var draft: []
    property string selected: ""
    property bool dirty: false
    // What the generator says of the draft ({ ok, error })
    readonly property var draftCheck: Monitors.generate(Monitors.normalize(draft), Monitors.modesOf(screens),
                                                        Serialize.luaValue)
    onScreensChanged: if (!dirty) resetDraft()
    function copy(list) {
        return list.map(s => Object.assign({}, s, { mode: s.mode ? Object.assign({}, s.mode) : null }))
    }
    function resetDraft() {
        draft = copy(screens)
        dirty = false
        if (!draft.some(s => s.name === selected)) {
            const first = draft.find(s => s.enabled) || draft[0]
            selected = first ? first.name : ""
        }
    }
    function select(name) {
        if (draft.some(s => s.name === name))
            selected = name
    }
    // The screens on (not mirrors) as boxes, and where each one is
    function boxes(list) {
        return list.filter(s => s.enabled && !s.mirror && s.mode).map(s => Object.assign(Monitors.box(s), { name: s.name }))
    }
    // A change to one screen of the draft; false (and why) when refused
    function edit(name, change) {
        const next = copy(draft)
        const s = next.find(x => x.name === name)
        if (!s)
            return false
        if (change.enabled === false && s.enabled
                && next.filter(x => x.enabled && !x.mirror && x.name !== name).length === 0) {
            fail("Pelo menos uma tela precisa ficar ligada")
            return false
        }
        // Turned on, or no longer a mirror: it needs a mode and a place
        const placing = (change.enabled === true && !s.enabled) || (change.mirror === "" && s.mirror !== "")
        Object.assign(s, change)
        if (placing && s.enabled) {
            if (!s.mode) {
                const first = s.modes.map(Monitors.parseMode).find(m => m)
                s.mode = first || null
            }
            s.scale = 1
            s.transform = 0
            s.mirror = ""
            const spot = Monitors.placeRight(boxes(next.filter(x => x.name !== name)))
            s.x = spot.x
            s.y = spot.y
        }
        // A new mode keeps the scale only if it still fits
        if (change.mode && !Monitors.scalesFor(s.mode).includes(s.scale))
            s.scale = 1
        if (!s.enabled)
            next.forEach(x => { if (x.mirror === name) x.mirror = "" })
        draft = next
        dirty = true
        message = ""
        return true
    }
    // A dragged screen dropped at x, y (arrangement pixels): its snapped spot
    function snapped(name, x, y) {
        const list = boxes(draft)
        const i = list.findIndex(b => b.name === name)
        return i < 0 ? { x: x, y: y } : Monitors.snap(list, i, x, y, 40)
    }
    function moveTo(name, x, y) {
        const spot = snapped(name, x, y)
        return edit(name, { x: spot.x, y: spot.y })
    }
    function applyDraft() {
        if (!dirty || !draftCheck.ok)
            return false
        return preview(Monitors.normalize(draft))
    }

    // local.lua with monitor lines (outside comments): it loads last and
    // wins over the page
    property bool localLuaHasMonitors: false
    FileView {
        path: `${root.hyprDir}/local.lua`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.localLuaHasMonitors = text().split("\n").some(l => !/^\s*--/.test(l) && /\bhl\.monitor\s*\(/.test(l))
        onLoadFailed: root.localLuaHasMonitors = false
    }

    // ── Commands (argument lists only) ──
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
