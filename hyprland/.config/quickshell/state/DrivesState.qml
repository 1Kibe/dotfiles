pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/devices.js" as Devices

// Removable drives (Configurações → Dispositivos), the one place that mounts
// them: the page and, later, the file manager read and act through here.
//
// - Watching: `udevadm monitor` on block devices runs from the shell's start
//   and is only a trigger: each event (after a short wait) asks for a new
//   lsblk, and the list comes from that alone (settings/devices.js:
//   pendrives, external disks and cards on USB or a card reader, never a
//   disk of the system).
// - Mounting on its own: only a drive plugged in after the shell started,
//   with a vfat or exfat filesystem, "Montar sozinho" on, and the session
//   unlocked when it was plugged and again right before mounting. Unlocked
//   means LockState says so and every screen is free of Hyprland's session
//   lock (hyprctl monitors, the compositor's own word, so also a lock this
//   shell does not know about); any doubt counts as locked. A drive plugged
//   while locked never mounts on its own, not even after unlocking. Nothing
//   mounts at the shell's start: what is already there waits for "Montar".
// - Every action (mount, eject) goes through one serial queue: a fresh lsblk
//   first, the drive must still be the same one (its token: name, size,
//   filesystem, label) and in the state the action needs. One command of
//   each kind at a time, each with a time limit; one that does not end (a
//   process stuck in the kernel) is never started again on top of it. At
//   most 3 failed tries per drive and one automatic mount a minute, then
//   only by hand.
// - Commands as argument lists: `udisksctl mount -t <fstype>` (never -o: the
//   options are mount_options.conf's), `unmount` (never -f), `power-off` of
//   the disk only with every partition of it unmounted. The mount point is
//   read from lsblk afterwards and checked (under /run/media/<user>/). Labels
//   and paths never go to a log.
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || ""
    readonly property bool autoMount: SettingsStore.ready ? SettingsStore.get("autoMount") !== false : false
    // [{ token, label, size, fstype, mounted, mountpoint, avail, auto,
    //    state: "free" | "mounting" | "mounted" | "ejecting", lockedPlug }]
    property var drives: []
    // A short fixed text for the page (never a label or a path)
    signal notice(string text)

    // token → { lockedPlug }: drives plugged now, seen since the start
    property var known: ({})
    // token → failed tries; kept when a drive is unplugged (plugging it
    // again does not reset the count), the newest 64 only
    property var failures: ({})
    property bool scanned: false
    property var raw: []
    property double lastAutoMs: 0
    property int maxFailures: 3
    property int autoGapMs: 60000
    property int mountLimitMs: 60000

    function locked() {
        return LockState.locked || LockState.wanted
    }

    // ── The list ──
    function publish() {
        const ops = {}
        for (const op of queue.concat(current ? [current] : []))
            ops[op.token] = op.kind
        drives = raw.map(d => {
            const t = Devices.driveToken(d)
            const k = known[t] || { lockedPlug: false }
            const busy = ops[t]
            return {
                token: t, label: d.label, size: d.size, fstype: d.fstype, mounted: d.mounted,
                mountpoint: d.mountpoint, avail: d.avail, auto: d.auto, lockedPlug: k.lockedPlug,
                state: busy === "eject" ? "ejecting" : (busy === "mount" || busy === "auto") ? "mounting"
                     : d.mounted ? "mounted" : "free"
            }
        })
    }
    function find(token, list) {
        return (list || raw).find(d => Devices.driveToken(d) === token) || null
    }

    // A scan: the new list; drives seen for the first time after the first
    // scan are new plugs, judged against the lock below
    function onScan(out) {
        const list = Devices.parseLsblk(out, user)
        const now = {}
        const fresh = []
        for (const d of list) {
            const t = Devices.driveToken(d)
            now[t] = true
            if (known[t] === undefined) {
                known[t] = { lockedPlug: false }
                if (scanned)
                    fresh.push(t)
            }
        }
        for (const t of Object.keys(known))
            if (!now[t])
                delete known[t]
        raw = list
        scanned = true
        if (fresh.length > 0)
            judge(fresh)
        publish()
    }

    // New plugs: locked now (LockState, then the screens) marks them for
    // good; unlocked ones that may mount on their own go to the queue
    // Each check judges only the plugs that came before it started; later
    // ones wait for the next check
    property var waiting: []
    function judge(tokens) {
        if (locked()) {
            tokens.forEach(t => { if (known[t]) known[t].lockedPlug = true })
            return
        }
        waiting = waiting.concat(tokens)
        if (plugCheck.running)
            return
        const ts = waiting
        waiting = []
        checkLock(plugCheck, free => {
            for (const t of ts) {
                if (!known[t])
                    continue
                if (!free || locked()) {
                    known[t].lockedPlug = true
                    continue
                }
                const d = find(t)
                if (d && d.auto && !d.mounted && autoMount && failed(t) < maxFailures)
                    enqueue("auto", t)
            }
            publish()
            if (waiting.length > 0)
                Qt.callLater(() => judge([]))
        })
    }
    function checkLock(job, done) {
        run(job, ["hyprctl", "-j", "monitors"], 3000,
            (code, out) => done(code === 0 && Devices.screensUnlocked(out) && !root.locked()))
    }
    // A Job that will not start (one still running, maybe stuck): the answer
    // is a failure, never a wait
    function run(job, cmd, ms, cb) {
        if (!job.start(cmd, ms, cb))
            Qt.callLater(() => cb(-1, "", ""))
    }

    // ── Actions (the page) ──
    function mount(token) {
        if (!locked() && find(token))
            enqueue("mount", token)
    }
    function eject(token) {
        if (!locked() && find(token))
            enqueue("eject", token)
    }
    function open(token) {
        const d = find(token)
        if (!d || !Devices.validMountpoint(d.mountpoint, user))
            return
        Quickshell.execDetached(["thunar", "--", d.mountpoint])
    }

    // ── The serial queue ──
    property var queue: []
    property var current: null
    function enqueue(kind, token) {
        if ((current && current.token === token) || queue.some(op => op.token === token))
            return
        queue = queue.concat([{ kind: kind, token: token }])
        publish()
        next()
    }
    function next() {
        if (current || queue.length === 0)
            return
        current = queue[0]
        queue = queue.slice(1)
        publish()
        // A fresh list before acting
        scan(ok => {
            if (!ok)
                return finish(false, "Não deu para ler as unidades")
            const d = find(current.token)
            if (!d)
                return finish(false, "")
            if (current.kind === "auto")
                return autoStep(d)
            if (current.kind === "mount")
                return d.mounted ? finish(true, "") : mountStep(d)
            return ejectStep(d)
        })
    }
    function failed(token) {
        return failures[token] || 0
    }
    function finish(ok, text) {
        const op = current
        current = null
        if (op && !ok) {
            const f = Object.assign({}, failures)
            delete f[op.token]
            f[op.token] = failed(op.token) + 1
            const keys = Object.keys(f)
            keys.slice(0, Math.max(0, keys.length - 64)).forEach(k => delete f[k])
            failures = f
        }
        if (text !== "")
            notice(text)
        publish()
        Qt.callLater(next)
    }
    function autoStep(d) {
        const t = current.token
        if (d.mounted || !d.auto || !autoMount || known[t].lockedPlug || failed(t) >= maxFailures)
            return finish(true, "")
        if (Date.now() - lastAutoMs < autoGapMs)
            return finish(true, "")
        // The lock read again right before mounting
        checkLock(lockCheck, free => {
            if (!free || locked()) {
                known[t].lockedPlug = true
                return finish(true, "")
            }
            lastAutoMs = Date.now()
            mountStep(d, true)
        })
    }
    function mountStep(d, automatic) {
        const t = current.token
        if (mountJob.running)
            return finish(false, "Uma montagem anterior ainda não terminou")
        run(mountJob, ["udisksctl", "mount", "--no-user-interaction", "-b", d.dev, "-t", d.fstype], mountLimitMs, (code, out, err) => {
            if (code !== 0)
                return finish(false, "Não deu para montar a unidade")
            // The mount point from a new lsblk, never from udisksctl's text
            scan(ok => {
                const m = find(t)
                const done = ok && m && m.mounted
                if (done && automatic)
                    notify(t)
                finish(done, done ? "" : "Não deu para montar a unidade")
            })
        })
    }
    function ejectStep(d) {
        const t = current.token
        if (mountJob.running)
            return finish(false, "Uma montagem anterior ainda não terminou")
        const powerOff = () => {
            scanRaw((ok, out) => {
                const parent = d.parent
                if (!ok || !Devices.diskUnmounted(out, parent))
                    return finish(true, "Desmontado")
                run(mountJob, ["udisksctl", "power-off", "--no-user-interaction", "-b", parent], 30000,
                               code => finish(true, code === 0 ? "Pode remover a unidade" : "Desmontado"))
            })
        }
        if (!d.mounted)
            return powerOff()
        run(mountJob, ["udisksctl", "unmount", "--no-user-interaction", "-b", d.dev], mountLimitMs, (code, out, err) => {
            if (code !== 0)
                return finish(false, Devices.busy(err) ? "Em uso: feche os arquivos e tente de novo"
                                                       : "Não deu para ejetar a unidade")
            powerOff()
        })
    }

    // ── The notification (until it is closed) ──
    function notify(token) {
        const d = find(token)
        if (!d || notifyJob.running)
            return
        run(notifyJob, ["notify-send", "-a", "Dispositivos", "-A", "open=Abrir", "-A", "eject=Ejetar", "--",
                         "Pendrive conectado", Devices.notifyLabel(d.label)], 600000, (code, out) => {
            const action = String(out).trim()
            // The same drive, still there
            if (!find(token))
                return
            if (action === "open")
                open(token)
            else if (action === "eject")
                eject(token)
        })
    }

    // ── Reading ──
    // One lsblk at a time; callers waiting for it get the same answer
    property var scanWaiters: []
    function scanRaw(done) {
        // One stuck past its limit: no answer will come, so a failure now
        if (lsblkJob.running && lsblkJob.timedOut)
            return Qt.callLater(() => done(false, ""))
        scanWaiters = scanWaiters.concat([done])
        if (lsblkJob.running)
            return
        lsblkJob.start(["lsblk", "-J", "-b", "-o", "NAME,PKNAME,LABEL,SIZE,FSTYPE,FSAVAIL,MOUNTPOINTS,RM,HOTPLUG,TRAN,TYPE"], 10000,
                       (code, out) => {
            const ws = scanWaiters
            scanWaiters = []
            const ok = code === 0
            if (ok)
                onScan(out)
            ws.forEach(w => w(ok, out))
        })
    }
    function scan(done) {
        scanRaw(ok => done(ok))
    }
    function refresh() {
        scanRaw(() => {})
    }

    // The trigger: block events, a short wait, a new list
    Process {
        id: watcher
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
        onRunningChanged: {
            if (running) {
                root.refresh()
            } else if (!root.stopping) {
                // Back after a wait that grows (never in a loop)
                watcherBack.interval = Math.min(watcherBack.interval * 2, 60000)
                watcherBack.restart()
            }
        }
    }
    property bool stopping: false
    Component.onCompleted: refresh()
    Component.onDestruction: stopping = true
    Timer {
        id: watcherBack
        interval: 2500
        onTriggered: watcher.running = true
    }
    Timer {
        id: settle
        interval: 700
        onTriggered: root.refresh()
    }

    // A command with a time limit: done(code, stdout, stderr), once. Only a
    // normal exit counts (status 0); past the limit it is stopped and
    // counts as failed, and while it has not ended it is never started again
    component Job: Process {
        id: job
        property var done: null
        property int code: -1
        property bool gotExit: false
        property bool gotOut: false
        property bool gotErr: false
        property bool timedOut: false
        stdout: StdioCollector {
            id: jobOut
            onStreamFinished: {
                job.gotOut = true
                job.settle()
            }
        }
        stderr: StdioCollector {
            id: jobErr
            onStreamFinished: {
                job.gotErr = true
                job.settle()
            }
        }
        function start(cmd, ms, cb) {
            if (running)
                return false
            done = cb
            code = -1
            gotExit = false
            gotOut = false
            gotErr = false
            timedOut = false
            command = cmd
            limit.interval = ms
            limit.restart()
            running = true
            return true
        }
        function settle() {
            if (!gotExit || !gotOut || !gotErr || done === null)
                return
            const cb = done
            done = null
            limit.stop()
            cb(timedOut ? -1 : code, jobOut.text, jobErr.text)
        }
        onExited: (exitCode, exitStatus) => {
            code = exitStatus === 0 ? exitCode : -1
            gotExit = true
            settle()
            if (done !== null)
                outWait.restart()
        }
        onRunningChanged: {
            // A command that cannot start never sends exited
            if (!running && !gotExit)
                Qt.callLater(() => {
                    if (!job.gotExit && job.done !== null) {
                        job.gotExit = true
                        job.gotOut = true
                        job.gotErr = true
                        job.code = -1
                        job.settle()
                    }
                })
        }
        property Timer outWait: Timer {
            interval: 1000
            onTriggered: {
                job.gotOut = true
                job.gotErr = true
                job.settle()
            }
        }
        // Past the limit: stopped, and the answer is a failure at once (a
        // process stuck in the kernel may never end; `running` then stays
        // true and start() refuses another one)
        property Timer limit: Timer {
            onTriggered: {
                job.timedOut = true
                job.running = false
                job.gotExit = true
                job.gotOut = true
                job.gotErr = true
                job.settle()
            }
        }
    }
    Job { id: lsblkJob }
    Job { id: lockCheck }
    Job { id: plugCheck }
    Job { id: mountJob }
    Job { id: notifyJob }
}
