pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../settings/keyboard.js" as Keyboard
import "../settings/serialize.js" as Serialize

// Configurações → Teclado e mouse → Layout, outside the page: the system's
// keyboard (the login's, from localectl), trying a layout before keeping it,
// and setting it for the login too.
//
// preview() takes only a layout from the system's own list
// (state/SystemLists). It first arms the way back, outside the shell: a
// systemd timer that runs `hyprctl reload` in 15 s (Hyprland's files come
// back even if the shell has died); a timer left from before refuses the
// preview and nothing is removed blindly. Only then the layout goes to
// Hyprland with `hyprctl eval`, nothing saved. A second preview applies over
// it without a new timer or more time.
//
// keep() stops the timer, saves the layout (the generated Hyprland file
// takes it) and, a second later, sets it for the login with `localectl
// set-x11-keymap`, through the system's own password window (polkit) and
// only when the login has another layout. Cancelled or failed: the page's
// layout goes back to the system's, with a fixed message, and nothing is
// tried again. useForLogin() is the same last step, from the page's button.
//
// localectl runs only from those two (a click on the page): never from a
// change of the settings, at start or from "Restaurar". Nothing here runs
// while the session is locked. Every command is an argument list; the
// layout, the model and the options pass settings/keyboard.js first.
Singleton {
    id: root

    readonly property string unit: "hypr-teclado-voltar"
    readonly property int seconds: 15
    readonly property string localFile: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr/local.lua`

    // The system's keyboard: { layout, model, variant, options } ("" =
    // unknown or left out); read at start and after each change
    property var system: ({ layout: "", model: "", variant: "", options: "" })
    property bool systemRead: false
    // The page's last refusal or failure ("" when fine)
    property string message: ""
    signal failed(string message)

    // The preview: on while the way back is armed and has not fired
    property bool pending: false
    property double deadline: 0
    property string tried: ""
    // Arming, keeping or waiting for localectl: one thing at a time
    property bool busy: false
    property bool settingLogin: false
    property bool ownReload: false

    function locked() {
        return LockState.locked || LockState.wanted
    }
    function fail(text) {
        message = text
        failed(text)
    }
    function usable(layout) {
        return SystemLists.layoutsRead && SystemLists.has("layouts", layout)
    }

    // ── The system's keyboard ──
    // done(ok): ok only with a real reading (exit 0 and the "X11 Layout"
    // line); otherwise `system` stays as it was
    function readSystem(done) {
        run(["env", "LC_ALL=C", "localectl", "--no-pager", "status"], (code, out) => {
            const read = code === 0 ? Keyboard.parseStatus(out) : null
            const ok = read !== null && read.known
            if (ok)
                root.system = read
            root.systemRead = true
            if (done)
                done(ok)
        })
    }
    Component.onCompleted: readSystem()

    // ── Try ──
    function preview(layout) {
        if (locked()) {
            fail("Com a sessão travada, o teclado não muda")
            return false
        }
        if (busy || settingLogin)
            return false
        if (MonitorsApply.pending) {
            fail("Espere a prévia das telas acabar")
            return false
        }
        if (!usable(layout)) {
            fail("Esse layout não está na lista do sistema")
            return false
        }
        message = ""
        if (pending) {
            // Over the running preview: same timer, no more time; not in its
            // last half second (the way back is about to fire)
            if (Date.now() >= deadline - 500) {
                fail("A prévia está acabando: espere ela voltar")
                return false
            }
            tried = layout
            apply(layout)
            return true
        }
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
        if (!/^[A-Za-z0-9_]{1,128}$/.test(sig)) {
            fail("Não achei a sessão do Hyprland")
            return false
        }
        busy = true
        // A way back left from before: refuse, remove nothing
        let armedAt = 0
        run(["systemctl", "--user", "show", "-p", "LoadState", "--value", `${unit}.timer`, `${unit}.service`],
            (code, out) => {
            if (code !== 0 || out.split("\n").filter(l => l.trim() !== "").some(l => l.trim() !== "not-found")) {
                root.busy = false
                root.fail("Uma volta de antes ainda está armada: espere ela acabar")
                return
            }
            // AccuracySec: a transient timer may otherwise fire up to a
            // minute late (systemd's default accuracy). The deadline counts
            // from before the call (the timer may already be running)
            armedAt = Date.now()
            run(["systemd-run", "--user", "--collect", `--unit=${root.unit}`, `--on-active=${root.seconds}s`,
                 "--timer-property=AccuracySec=100ms", `--setenv=HYPRLAND_INSTANCE_SIGNATURE=${sig}`,
                 "hyprctl", "reload"], code2 => {
                root.busy = false
                if (code2 !== 0) {
                    root.fail("Não deu para armar a volta: nada foi aplicado")
                    return
                }
                root.pending = true
                root.deadline = armedAt + root.seconds * 1000
                expiry.interval = Math.max(0, root.deadline - Date.now()) + 1500
                expiry.restart()
                root.tried = layout
                root.apply(layout)
            })
        })
        return true
    }
    function apply(layout) {
        let code = ""
        try {
            code = Keyboard.previewCode(layout, Serialize.luaValue)
        } catch (e) {
            fail("Esse layout não está na lista do sistema")
            revert()
            return
        }
        run(["hyprctl", "eval", code], result => {
            if (result !== 0) {
                root.fail("O Hyprland não aceitou o layout")
                root.revert()
            }
        })
    }

    // ── Keep ──
    function keep() {
        if (locked() || !pending || Date.now() >= deadline || busy || !usable(tried))
            return false
        const layout = tried
        busy = true
        run(["systemctl", "--user", "stop", `${unit}.timer`], code => {
            // The timer may have fired meanwhile: then the preview is over
            if (code !== 0 || !root.pending || Date.now() >= root.deadline) {
                root.busy = false
                root.fail("A prévia acabou antes de manter: nada foi gravado")
                return
            }
            // Locked meanwhile: nothing is saved, the saved layout comes back
            // (the timer is already stopped)
            if (root.locked()) {
                root.busy = false
                root.endPreview("")
                root.reload()
                root.fail("Com a sessão travada, nada foi gravado: voltou ao layout salvo")
                return
            }
            root.endPreview("")
            SettingsStore.set("kbLayout", layout)
            root.busy = false
            root.wanted = layout
            loginTimer.restart()
        })
        return true
    }
    // A second after keeping (the Hyprland file written and read): the login
    property string wanted: ""
    Timer {
        id: loginTimer
        interval: 1000
        onTriggered: root.setLogin(root.wanted)
    }
    // The page's "Usar também no login" (the layout already in use)
    function useForLogin() {
        const layout = SettingsStore.get("kbLayout")
        if (locked() || pending || busy || settingLogin || !usable(layout))
            return false
        setLogin(layout)
        return true
    }
    // The system's layout, read first: localectl only when it differs. One
    // at a time; the password is asked by the system's window (polkit)
    function setLogin(layout) {
        if (settingLogin)
            return
        if (locked()) {
            fail("Com a sessão travada, o teclado do login não mudou")
            return
        }
        settingLogin = true
        readSystem(ok => {
            // No real reading: never call localectl (it would ask the password
            // for nothing, or wipe the system's model and options)
            if (!ok) {
                root.settingLogin = false
                root.fail("Não deu para trocar o layout")
                return
            }
            if (root.system.layout === layout) {
                root.settingLogin = false
                return
            }
            const args = Keyboard.setArgs(layout, root.system, SystemLists.layouts)
            if (args === null || root.locked()) {
                root.settingLogin = false
                root.fail("Não deu para trocar o layout")
                return
            }
            root.run(args, code => {
                root.readSystem(ok2 => {
                    root.settingLogin = false
                    if (code === 0 && ok2 && root.system.layout === layout)
                        return
                    if (code === 0 && !ok2) {
                        root.fail("Não deu para conferir o teclado do login")
                        return
                    }
                    // Cancelled or failed: the page goes back to the system's
                    // layout (when it is a known one), never tried again; with
                    // the session locked nothing is saved
                    if (ok2 && root.usable(root.system.layout) && !root.locked())
                        SettingsStore.set("kbLayout", root.system.layout)
                    root.fail("Não deu para trocar o layout")
                })
            })
        })
    }

    // ── Back ──
    function revert() {
        if (!pending)
            return
        endPreview("Voltou ao layout salvo")
        run(["systemctl", "--user", "stop", `${unit}.timer`], () => root.reload())
    }
    // Hyprland's files again (the saved layout); a reload that fails says so
    function reload() {
        ownReload = true
        ownReloadTimer.restart()
        run(["hyprctl", "reload"], code => {
            if (code !== 0) {
                root.ownReload = false
                root.fail("Não deu para voltar o layout: recarregue o Hyprland")
            }
        })
    }
    // Our reload's event, if it never comes, must not swallow a later one
    Timer {
        id: ownReloadTimer
        interval: 2000
        onTriggered: root.ownReload = false
    }
    function endPreview(text) {
        pending = false
        deadline = 0
        tried = ""
        expiry.stop()
        if (text)
            message = text
    }
    // A reload while previewing ends it (the timer's, or anyone's)
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
                root.endPreview("A prévia acabou: voltou ao layout salvo")
        }
    }
    // The timer's own end, also when the reload event is missed
    Timer {
        id: expiry
        onTriggered: {
            if (root.pending) {
                root.endPreview("A prévia acabou: voltou ao layout salvo")
                // The timer outside should have done it: once more, here
                root.reload()
            }
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

    // local.lua with a kb_layout line (outside comments): it loads last and
    // wins over the page
    property bool localSetsLayout: false
    FileView {
        path: root.localFile
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.localSetsLayout = Keyboard.localSetsLayout(text())
        onLoadFailed: root.localSetsLayout = false
    }

    // ── Commands (argument lists only) ──
    // A command's end: its exit and all of its output (the output may land
    // after the exit). A command that cannot start ends with -1; an output
    // that never closes is given up a second after the exit
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
