pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.state
import "../control/lists.js" as Lists

// The updates waiting, for the control center's Atualizações section and
// its button. Nothing updates by itself: this only checks, with fixed
// commands, one after the other: "checkupdates" (pacman, no root) and
// "paru -Qua" (AUR), both in the C locale, checkupdates with its database
// in a 0700 folder of the session's runtime directory. The output is read
// line by line by a fixed pattern ("name old -> new"), at most 2000 lines;
// anything else is dropped, never shown. Exit codes: checkupdates 0 found,
// 2 nothing, anything else failed; paru 0 found, 1 with no lines nothing,
// anything else failed. A failure keeps the counts from before (it never
// turns into "em dia"), and each origin keeps its own state; a missing
// program is a state of its own. Everything stays in memory.
//
// The clock: the first check 2 min after the shell starts, then every
// ~6 h; a failed one is tried again in 15 min, 1 h, then 6 h. Never while
// the session is locked (it waits for the unlock). One check at a time,
// each command 90 s at most and ending with the shell. "Verificar agora"
// runs one right away. This is the one thing of the control center that
// runs with it closed.
Singleton {
    id: root

    // Each origin: state ("idle", "checking", "ok", "failed", "missing"),
    // count (-1 never known) and the packages ({ name, from, to })
    property var sys: ({ state: "idle", count: -1, list: [] })
    property var aur: ({ state: "idle", count: -1, list: [] })
    readonly property bool checking: sys.state === "checking" || aur.state === "checking"
    readonly property var summary: Lists.updatesSummary({ sys: sys, aur: aur })
    property int failures: 0
    // The wait until the next check by the clock
    property int nextMs: 0
    // Shortened by a test
    property int firstDelayMs: 120000
    property int timeoutMs: 90000
    readonly property var retryMs: [15 * 60000, 60 * 60000, 6 * 3600000]
    readonly property int everyMs: 6 * 3600000

    readonly property bool locked: LockState.wanted || LockState.locked
    property bool dueWhileLocked: false

    // The checkupdates database: a folder of the runtime directory (a plain
    // absolute path; the script makes it 0700 and checks it is ours)
    readonly property string dbDir: {
        const r = Quickshell.env("XDG_RUNTIME_DIR") || ""
        return /^\/[A-Za-z0-9._\/-]{1,200}$/.test(r) && !r.includes("..") ? r + "/qs-checkupdates" : ""
    }

    // Fixed scripts; "exit 90" is "not installed"
    readonly property string sysScript: [
        'umask 077',
        'mkdir -p "$1" && [ -O "$1" ] && chmod 700 "$1" || exit 91',
        'command -v checkupdates >/dev/null 2>&1 || exit 90',
        'CHECKUPDATES_DB="$1" LC_ALL=C exec setpriv --pdeathsig TERM -- checkupdates'
    ].join("\n")
    readonly property string aurScript: [
        'command -v paru >/dev/null 2>&1 || exit 90',
        'LC_ALL=C exec setpriv --pdeathsig TERM -- paru -Qua --color never'
    ].join("\n")

    // The hook for the notifications module, once it exists: the count only
    function notify(count) {
    }

    function checkNow() {
        check()
    }
    function check() {
        if (checking)
            return
        if (locked) {
            dueWhileLocked = true
            return
        }
        dueWhileLocked = false
        clock.stop()
        start(sysJob, "sys")
    }

    property var found: []
    property int lines: 0
    property bool overflow: false
    property string origin: ""
    function start(job, which) {
        origin = which
        found = []
        lines = 0
        overflow = false
        if (which === "sys")
            sys = { state: "checking", count: sys.count, list: sys.list }
        else
            aur = { state: "checking", count: aur.count, list: aur.list }
        if (which === "sys" && dbDir === "") {
            done("sys", 91)
            return
        }
        job.command = which === "sys" ? ["sh", "-c", sysScript, "sh", dbDir] : ["sh", "-c", aurScript, "sh"]
        deadline.interval = timeoutMs
        deadline.restart()
        job.running = true
    }
    function readLine(line) {
        if (overflow)
            return
        if (++lines > Lists.UPDATES_MAX_LINES) {
            overflow = true
            sysJob.running = false
            aurJob.running = false
            return
        }
        const u = Lists.updateLine(line)
        if (u !== null)
            found.push({ name: Lists.trim(u.name), from: Lists.trim(u.from), to: Lists.trim(u.to) })
    }
    function done(which, code) {
        deadline.stop()
        const before = which === "sys" ? sys : aur
        let next
        if (overflow || code === null)
            next = { state: "failed", count: before.count, list: before.list }
        else if (code === 90)
            next = { state: "missing", count: -1, list: [] }
        else if (code === 0 || (which === "sys" && code === 2) || (which === "aur" && code === 1 && found.length === 0))
            next = { state: "ok", count: found.length, list: found }
        else
            next = { state: "failed", count: before.count, list: before.list }
        found = []
        if (which === "sys") {
            sys = next
            start(aurJob, "aur")
            return
        }
        aur = next
        origin = ""
        const failed = sys.state === "failed" || aur.state === "failed"
        failures = failed ? failures + 1 : 0
        nextMs = failed ? retryMs[Math.min(failures, retryMs.length) - 1] : everyMs
        clock.interval = nextMs
        clock.restart()
        const total = Math.max(0, sys.count) + Math.max(0, aur.count)
        if (total > 0)
            notify(total)
    }

    // No reader for the error output: it would carry package names
    Process {
        id: sysJob
        stdout: SplitParser {
            onRead: line => root.readLine(line)
        }
        onExited: code => root.done("sys", code)
    }
    Process {
        id: aurJob
        stdout: SplitParser {
            onRead: line => root.readLine(line)
        }
        onExited: code => root.done("aur", code)
    }
    // 90 s for the running command: stopped, and a failure
    Timer {
        id: deadline
        onTriggered: {
            root.overflow = true
            sysJob.running = false
            aurJob.running = false
        }
    }

    Timer {
        id: first
        interval: root.firstDelayMs
        running: true
        onTriggered: root.check()
    }
    Timer {
        id: clock
        onTriggered: root.check()
    }
    // A check that came due while locked runs at the unlock
    onLockedChanged: {
        if (!locked && dueWhileLocked)
            check()
    }

    // "Atualizar tudo no terminal": a fixed script of the repo in Kitty, in
    // the control center's special workspace (hypr/modules/rules.lua); the
    // password is typed there, never here. Clicks within 3 s are ignored.
    property double openedAt: 0
    function openTerminal() {
        if (locked || Date.now() - openedAt < 3000)
            return false
        openedAt = Date.now()
        Quickshell.execDetached(["kitty", "--class", "qs-central", "hypr-atualizar"])
        return true
    }
}
