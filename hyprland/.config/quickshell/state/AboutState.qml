pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/about.js" as About
import "../settings/schema.js" as Schema
import "../settings/validate.js" as Validate
import "../settings/serialize.js" as Serialize

// Configurações → Sobre, outside the page: the repo's version, the system,
// and Exportar.
//
// The repo is the one this shell runs from (the real path of the shell's
// folder, <repo>/hyprland/.config/quickshell). git is asked only if the repo
// folder and its .git are the user's own, real folders (no link) that no
// one else can write to; then only four questions, with a fixed command line
// and an empty environment but for a few fixed values: no system or global
// config, no hooks, no fsmonitor, no pager, no prompt, no locks, no
// signature check (no gpg or ssh program), and never a command that runs the
// repo's filters or reaches the network. Every answer passes settings/about.js;
// anything else reads "—". The system is read as data only. Every command
// has ten seconds.
//
// Exportar writes the repo's settings/defaults.json (its real path, never
// through a link: the settings folder must be the user's own real folder
// and the file a plain one), exactly the plan the page showed and the user
// confirmed (settings/about.js exportPlan); it never stages, commits or
// pushes.
Singleton {
    id: root

    readonly property string none: About.NONE
    readonly property string githubUrl: "https://github.com/1Kibe/dotfiles"
    readonly property string home: Quickshell.env("HOME")

    property string repo: ""
    property bool repoOk: false
    property bool checked: false
    property string branch: none
    property string commit: none
    property string date: none
    property string tag: none
    property string distro: none
    property string kernel: none
    property string hyprland: none
    property string quickshell: none
    property string cpu: none
    property string memory: none
    property string uid: ""

    function refresh() {
        run(["id", "-u"], (code, out) => {
            root.uid = out.trim()
            root.findRepo()
        })
        readSystem()
    }
    Component.onCompleted: refresh()

    // ── The repo ──
    function findRepo() {
        run(["readlink", "-f", "--", Quickshell.shellPath(".")], (code, out) => {
            const shell = out.trim()
            const suffix = "/hyprland/.config/quickshell"
            if (code !== 0 || !shell.endsWith(suffix) || !shell.startsWith("/")) {
                root.noRepo()
                return
            }
            const repo = shell.slice(0, shell.length - suffix.length)
            root.statOwn(repo, ok => {
                if (!ok)
                    return root.noRepo()
                root.statOwn(`${repo}/.git`, ok2 => {
                    if (!ok2)
                        return root.noRepo()
                    root.repo = repo
                    root.repoOk = true
                    root.checked = true
                    root.askGit()
                })
            })
        })
    }
    function noRepo() {
        repo = ""
        repoOk = false
        checked = true
        branch = none
        commit = none
        date = none
        tag = none
    }
    // The user's own real folder (stat does not follow links) with no write
    // for group or others
    function statOwn(path, done) {
        run(["stat", "-c", "%u %f", "--", path], (code, out) => {
            const m = out.trim().match(/^(\d+) ([0-9a-fA-F]+)$/)
            if (code !== 0 || !m || m[1] !== root.uid)
                return done(false)
            const mode = parseInt(m[2], 16)
            done((mode & 0o170000) === 0o040000 && (mode & 0o022) === 0)
        })
    }
    function git(args) {
        return ["env", "-i", "PATH=/usr/bin", `HOME=${home}`, "LC_ALL=C",
                "GIT_CONFIG_NOSYSTEM=1", "GIT_CONFIG_GLOBAL=/dev/null", "GIT_TERMINAL_PROMPT=0", "GIT_OPTIONAL_LOCKS=0",
                "/usr/bin/git", "--no-pager", "--no-optional-locks", "-C", repo,
                "-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-c", "core.pager=cat",
                "-c", "log.showSignature=false", "-c", "gpg.program=/bin/false", "-c", "gpg.ssh.program=/bin/false",
                "-c", "gpg.x509.program=/bin/false"].concat(args)
    }
    function askGit() {
        if (!repoOk)
            return
        run(git(["rev-parse", "--short=12", "HEAD"]), (code, out) => root.commit = code === 0 ? About.gitHash(out) : root.none)
        run(git(["log", "-1", "--no-show-signature", "--format=%cs"]), (code, out) => root.date = code === 0 ? About.gitDate(out) : root.none)
        run(git(["describe", "--tags", "--abbrev=0"]), (code, out) => root.tag = code === 0 ? About.gitRef(out) : root.none)
        run(git(["rev-parse", "--abbrev-ref", "HEAD"]), (code, out) => root.branch = code === 0 ? About.gitRef(out) : root.none)
    }

    // ── The system (data only; no machine or user name, serial, address) ──
    function readSystem() {
        run(["cat", "/etc/os-release"], (code, out) => root.distro = code === 0 ? About.osName(out) : root.none)
        run(["uname", "-r"], (code, out) => root.kernel = code === 0 ? About.kernel(out) : root.none)
        run(["cat", "/proc/cpuinfo"], (code, out) => root.cpu = code === 0 ? About.cpuModel(out) : root.none)
        run(["cat", "/proc/meminfo"], (code, out) => root.memory = code === 0 ? About.memory(out) : root.none)
        run(["hyprctl", "version", "-j"], (code, out) => root.hyprland = code === 0 ? About.hyprland(out) : root.none)
        run(["quickshell", "--version"], (code, out) => root.quickshell = code === 0 ? About.quickshell(out) : root.none)
    }

    function openGithub() {
        Quickshell.execDetached(["xdg-open", githubUrl])
    }

    // ── Exportar ──
    // What it would change now: { out, changed, skipped }
    function plan() {
        return About.exportPlan(Schema.KEYS, SettingsStore.values, SettingsStore.defaults, Validate.validate, home)
    }
    readonly property string defaultsTarget: repoOk ? `${repo}/hyprland/.config/quickshell/settings/defaults.json` : ""
    property string exportMessage: ""
    property bool exporting: false
    signal exported(int count)
    // `p`: the plan the page showed (plan()), written as it is
    function exportNow(p) {
        if (!SettingsStore.ready || !repoOk || exporting || !p || typeof p.out !== "object" || !Array.isArray(p.changed))
            return false
        exporting = true
        exportMessage = ""
        const refuse = () => {
            root.exporting = false
            root.exportMessage = "O defaults.json do repo é um link ou não pôde ser conferido: nada foi gravado"
        }
        // The folder must be the user's own real one and the file a plain file
        // (or missing): the write follows a link
        statOwn(`${repo}/hyprland/.config/quickshell/settings`, ok => {
            if (!ok)
                return refuse()
            run(Serialize.writeCheck(root.defaultsTarget), code => {
                if (!Serialize.mayWrite(code))
                    return refuse()
                exportView.count = p.changed.length
                exportView.path = root.defaultsTarget
                exportView.setText(JSON.stringify(p.out, null, 2) + "\n")
            })
        })
        return true
    }
    FileView {
        id: exportView
        property int count: 0
        printErrors: false
        atomicWrites: true
        onSaved: {
            root.exporting = false
            root.exportMessage = `${count} ${count === 1 ? "chave alterada" : "chaves alteradas"}; revise o git diff antes de qualquer commit`
            root.exported(count)
        }
        onSaveFailed: {
            root.exporting = false
            root.exportMessage = "Não deu para gravar o defaults.json do repo"
        }
    }

    // ── Commands (argument lists only, ten seconds at most) ──
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
        property Timer limit: Timer {
            interval: 10000
            running: true
            onTriggered: {
                job.running = false
                job.finish(-1, "")
            }
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
