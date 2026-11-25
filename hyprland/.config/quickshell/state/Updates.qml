pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import qs.state
import "../control/lists.js" as Lists

// The updates waiting, for the control center's Atualizações section and
// its button. Nothing updates by itself: this only checks, with fixed
// commands, one after the other: "checkupdates" (pacman, no root) and
// "paru -Qua" (AUR), both in the C locale, checkupdates with its database
// in a 0700 folder of the session's runtime directory. Each command runs
// under timeout (85 s, then killed 5 s later) and its output is cut at
// 1 MiB inside the child; here it is read line by line by a fixed pattern
// ("name old -> new"), at most 2000 lines; anything else is dropped, never
// shown, and the error output (it carries package names) is never read.
// Exit codes: checkupdates 0 found (at least one line in the pattern), 2
// nothing; paru 0 found (the same), 1 with no lines nothing; anything else,
// a process ended by a signal, too much output, or a 0 with no valid line
// failed. A failure keeps the counts from before (it never turns into "em
// dia"), and each origin keeps its own state; a missing program is a state
// of its own. Everything stays in memory.
//
// The clock: the first check 2 min after the shell starts, then every
// ~6 h; a failed one is tried again in 15 min, 1 h, then 6 h. Never while
// the session is locked, and never with no network at all (it waits for
// the unlock or the network, without counting a failure). One check at a
// time. "Verificar agora" runs one right away (ignored within 3 s), and
// its failure does not change the clock. This is the one thing of the
// control center that runs with it closed.
Singleton {
    id: root

    // Each origin: state ("idle", "checking", "ok", "failed", "missing"),
    // count (-1 never known), the packages ({ name, from, to }, those
    // shown) and why it is missing
    property var sys: ({ state: "idle", count: -1, list: [], missing: "" })
    property var aur: ({ state: "idle", count: -1, list: [], missing: "" })
    readonly property bool checking: origin !== ""
    // While a check runs the button keeps the last complete summary (one
    // origin new and the other old would add up to a total that never was)
    readonly property var summary: checking ? held : Lists.updatesSummary({ sys: sys, aur: aur })
    property var held: ({ text: "Verificando…", warn: false })
    onCheckingChanged: {
        if (checking)
            held = sys.count < 0 && aur.count < 0 ? { text: "Verificando…", warn: false }
                 : Lists.updatesSummary({ sys: sys, aur: aur })
    }
    property int failures: 0
    // When the last check ended (ms; 0 none yet)
    property double lastCheckAt: 0
    // The wait until the next check by the clock
    property int nextMs: 0
    // Shortened by a test
    property int firstDelayMs: 120000
    property int timeoutMs: 95000
    readonly property var retryMs: [15 * 60000, 60 * 60000, 6 * 3600000]
    readonly property int everyMs: 6 * 3600000

    readonly property bool locked: LockState.wanted || LockState.locked
    // No network at all (an unknown connectivity is tried)
    readonly property bool offline: Networking.connectivity === NetworkConnectivity.None
    property bool due: false

    // The checkupdates database: a folder of the runtime directory (a plain
    // absolute path; the script makes it 0700 and checks it is ours)
    readonly property string dbDir: {
        const r = Quickshell.env("XDG_RUNTIME_DIR") || ""
        return /^\/[A-Za-z0-9._\/-]{1,200}$/.test(r) && !r.includes("..") ? r + "/qs-checkupdates" : ""
    }

    // Fixed scripts (bash, for the exit code of the first command of the
    // pipe); 90 not installed, 92 no fakeroot (checkupdates needs it)
    readonly property string sysScript: [
        'umask 077',
        'mkdir -p "$1" && [ -O "$1" ] && chmod 700 "$1" || exit 91',
        'command -v checkupdates >/dev/null 2>&1 || exit 90',
        'command -v fakeroot >/dev/null 2>&1 || exit 92',
        'CHECKUPDATES_DB="$1" LC_ALL=C timeout -k 5 85 setpriv --pdeathsig TERM -- checkupdates | head -c 1048577',
        'exit "${PIPESTATUS[0]}"'
    ].join("\n")
    readonly property string aurScript: [
        'command -v paru >/dev/null 2>&1 || exit 90',
        'LC_ALL=C timeout -k 5 85 setpriv --pdeathsig TERM -- paru -Qua --color never | head -c 1048577',
        'exit "${PIPESTATUS[0]}"'
    ].join("\n")
    readonly property int maxBytes: 1048576

    // The notice (the notifications' own local path): the count only, and
    // only when it grew since the last notice (a check finding the same
    // ones says nothing again). "Ver" opens the control center's updates
    // section on the focused monitor
    property int noticed: 0
    property int lastNotice: 0
    function notify(count) {
        if (count <= noticed) {
            noticed = count
            return
        }
        noticed = count
        // The newer count replaces the older notice
        if (lastNotice > 0)
            NotificationState.dismiss(lastNotice)
        lastNotice = NotificationState.post("Atualizações", count === 1 ? "1 pacote para atualizar" : `${count} pacotes para atualizar`, "",
                               ["Ver"], index => {
            const m = Hyprland.focusedMonitor
            if (index === 0 && m)
                ShellState.openControl(ShellState.panelScreen(m.name), "updates", false)
        })
    }

    // "Verificar agora": ignored while one runs and within 3 s
    property double manualAt: 0
    // Also the IPC's check (qs ipc call updates check, which hypr-atualizar
    // calls when it ends): "ok", or why not: "travada" (it runs after the
    // unlock), "ocupada", "cedo".
    // With no network it is "ok" and waits for the network, as the clock.
    function checkNow() {
        // Locked: nothing runs now; it waits for the unlock, as the clock
        if (locked) {
            if (!checking)
                due = true
            return "travada"
        }
        if (checking)
            return "ocupada"
        if (Date.now() - manualAt < 3000)
            return "cedo"
        manualAt = Date.now()
        check(true)
        return "ok"
    }
    function check(manual) {
        if (checking)
            return
        first.stop()
        if (locked || offline) {
            due = true
            return
        }
        due = false
        byHand = manual === true
        if (!byHand)
            clock.stop()
        start("sys")
    }

    property bool byHand: false
    property var found: []
    property int lines: 0
    property int bytes: 0
    property bool overflow: false
    property string origin: ""
    function start(which) {
        origin = which
        found = []
        lines = 0
        bytes = 0
        overflow = false
        const before = which === "sys" ? sys : aur
        const now = { state: "checking", count: before.count, list: before.list, missing: "" }
        if (which === "sys")
            sys = now
        else
            aur = now
        if (which === "sys" && dbDir === "") {
            done("sys", 91, 0)
            return
        }
        const job = which === "sys" ? sysJob : aurJob
        job.command = which === "sys" ? ["bash", "-c", sysScript, "bash", dbDir] : ["bash", "-c", aurScript, "bash"]
        deadline.interval = timeoutMs
        deadline.restart()
        job.running = true
    }
    function readLine(which, line) {
        if (which !== origin || overflow)
            return
        bytes += line.length + 1
        if (++lines > Lists.UPDATES_MAX_LINES || bytes > maxBytes) {
            overflow = true
            sysJob.running = false
            aurJob.running = false
            return
        }
        const u = Lists.updateLine(line)
        if (u !== null)
            found.push(u.hidden ? u : { name: Lists.trim(u.name), from: Lists.trim(u.from), to: Lists.trim(u.to) })
    }
    // code: the exit code; status: 0 a normal exit, else ended by a signal
    function done(which, code, status) {
        if (which !== origin)
            return
        deadline.stop()
        stuck.stop()
        const before = which === "sys" ? sys : aur
        const failed = { state: "failed", count: before.count, list: before.list, missing: "" }
        let next
        if (overflow || status !== 0)
            next = failed
        else if (code === 90 || code === 92)
            next = { state: "missing", count: -1, list: [], missing: code === 92 ? "fakeroot" : which === "sys" ? "pacman-contrib" : "paru" }
        else if (code === 0 && found.length > 0)
            next = { state: "ok", count: found.length, list: found.filter(p => !p.hidden), missing: "" }
        else if (found.length === 0 && ((which === "sys" && code === 2) || (which === "aur" && code === 1)))
            next = { state: "ok", count: 0, list: [], missing: "" }
        else
            next = failed
        found = []
        if (which === "sys") {
            sys = next
            // Locked (or the network gone) in the middle: the AUR waits
            if (locked || offline) {
                origin = ""
                due = true
                return
            }
            start("aur")
            return
        }
        aur = next
        origin = ""
        lastCheckAt = Date.now()
        const anyFailed = sys.state === "failed" || aur.state === "failed"
        if (byHand && anyFailed) {
            // A failed check by hand leaves the clock as it is
            if (!clock.running) {
                nextMs = retryMs[0]
                clock.interval = nextMs
                clock.restart()
            }
        } else {
            failures = anyFailed ? failures + 1 : 0
            nextMs = anyFailed ? retryMs[Math.min(failures, retryMs.length) - 1] : everyMs
            clock.interval = nextMs
            clock.restart()
        }
        const total = Math.max(0, sys.count) + Math.max(0, aur.count)
        // (a failed check says nothing, and keeps the last count)
        if (!anyFailed)
            notify(total)
    }

    Process {
        id: sysJob
        stdout: SplitParser {
            onRead: line => root.readLine("sys", line)
        }
        onExited: (code, status) => root.done("sys", code, status)
    }
    Process {
        id: aurJob
        stdout: SplitParser {
            onRead: line => root.readLine("aur", line)
        }
        onExited: (code, status) => root.done("aur", code, status)
    }
    // Past its time the command is stopped; if it still does not end, the
    // step ends here anyway, so "checking" never stays on
    Timer {
        id: deadline
        onTriggered: {
            root.overflow = true
            sysJob.running = false
            aurJob.running = false
            stuck.restart()
        }
    }
    Timer {
        id: stuck
        interval: 5000
        onTriggered: root.done(root.origin, -1, 1)
    }

    Timer {
        id: first
        interval: root.firstDelayMs
        running: true
        onTriggered: root.check(false)
    }
    Timer {
        id: clock
        onTriggered: root.check(false)
    }
    // A check that came due while locked or offline runs once both are back
    onLockedChanged: {
        if (!locked && !offline && due)
            check(false)
    }
    onOfflineChanged: {
        if (!locked && !offline && due)
            check(false)
    }

    // "Atualizar tudo no terminal": a fixed script of the repo in Kitty, in
    // the control center's special workspace (hypr/modules/rules.lua); the
    // password is typed there, never here; the script itself refuses a
    // second one while one is open. Clicks within 3 s are ignored.
    property double openedAt: 0
    function openTerminal() {
        if (locked || Date.now() - openedAt < 3000)
            return false
        openedAt = Date.now()
        Quickshell.execDetached(["kitty", "--class", "qs-central", "hypr-atualizar"])
        return true
    }
}
