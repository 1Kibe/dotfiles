pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/devices.js" as Devices

// Printers (Configurações → Dispositivos): the queues CUPS has, their state,
// the jobs, the default printer and the network printer discovery.
//
// - Reading only while the page shows (`active`), every few seconds, one
//   command at a time, each with a time limit and LC_ALL=C (the texts are
//   parsed). Printer names come only from `lpstat -v` (configured queues;
//   never `lpstat -e`, which also lists printers announced on the network)
//   and are checked (settings/devices.js); the state of each one is the
//   first line of its own `lpstat -p <name>`, the job titles come from
//   `lpq -P <name>`.
// - Every command goes through `sh -c 'exec "$@"'` (see Job): names never in
//   the argv of a program that may be missing (Quickshell logs that argv).
// - Acting only on what the last reading listed, as argument lists, with no
//   "--" (lpstat, lpoptions and cancel would take it as a name; only lp
//   takes it, before the file): the default is the user's own
//   (`lpoptions -d`, no password), a job is cancelled only when it is the
//   user's (by its job number: CUPS numbers jobs for the whole system, so
//   the queue's name, which may start with a digit, is never read as a
//   number), the test page is CUPS's own file. Before each action the
//   queue is read again (`lpstat -p <name>`). A queue made from a printer
//   announced on the network is only shown ("da rede"). Adding a printer
//   opens system-config-printer; CUPS asks for a password unless the user
//   is in its SystemGroup (wheel on Arch), then it lets them in without one.
// - Network discovery: avahi, off by default. Only a click turns it on or
//   off, starting or stopping its service and socket together (systemd asks
//   for the password); it is never enabled, never touched at the start or by
//   Restaurar tudo. Its state is what systemd says of the two.
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || ""
    // The page sets it while it shows
    property bool active: false
    // [{ name, medium, state, announced }] and the default's name ("" when none)
    property var printers: []
    property string defaultPrinter: ""
    // [{ id, printer, number, mine, title }]
    property var jobs: []
    // "" not read yet, "ok", "none" (CUPS not there or not answering)
    property string status: ""
    property bool discovery: false
    property bool discoveryBusy: false
    // A short fixed text for the page
    signal notice(string text)

    readonly property string testFile: "/usr/share/cups/data/testprint"

    onActiveChanged: {
        if (active) {
            refresh()
            readDiscovery()
        }
    }
    // Every 15 s while the page shows (each lpstat wakes cupsd up through
    // its socket), and after each action
    Timer {
        interval: 15000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    // ── Reading: one pass, step by step ──
    property bool reading: false
    property bool again: false
    function refresh() {
        if (reading) {
            again = true
            return
        }
        reading = true
        readJob.run(["lpstat", "-v"], 8000, (code, out) => {
            if (code !== 0) {
                // No CUPS, or none configured: lpstat -v fails with no queue
                return endRead({ printers: [], def: "", jobs: [] }, "none")
            }
            const found = Devices.parsePrintersV(out)
            const names = found.map(p => p.name)
            readStates(found, 0, () => {
                readJob.run(["lpstat", "-d"], 8000, (dc, dout) => {
                    const def = dc === 0 ? Devices.parseDefault(dout, names) : ""
                    readJob.run(["lpstat", "-o"], 8000, (oc, oout) => {
                        const js = oc === 0 ? Devices.parseJobs(oout, names, user) : []
                        readTitles(js, names.filter(n => js.some(j => j.printer === n)), 0, {}, titled => {
                            endRead({ printers: found, def: def, jobs: titled }, "ok")
                        })
                    })
                })
            })
        })
    }
    function readStates(found, i, done) {
        if (i >= found.length)
            return done()
        readJob.run(["lpstat", "-p", found[i].name], 8000, (code, out) => {
            found[i].state = code === 0 ? Devices.parsePrinterState(out, found[i].name) : "unknown"
            readStates(found, i + 1, done)
        })
    }
    function readTitles(js, names, i, titles, done) {
        if (i >= names.length)
            return done(js.map(j => Object.assign({}, j, { title: (titles[j.printer] || {})[String(j.number)] || "" })))
        readJob.run(["lpq", "-P", names[i]], 8000, (code, out) => {
            titles[names[i]] = code === 0 ? Devices.parseTitles(out) : {}
            readTitles(js, names, i + 1, titles, done)
        })
    }
    function endRead(r, st) {
        printers = r.printers.map(p => ({ name: p.name, medium: p.medium, state: p.state || "unknown",
                                          announced: p.announced === true }))
        defaultPrinter = r.def
        jobs = r.jobs
        status = st
        reading = false
        const more = again
        again = false
        if (more && active)
            Qt.callLater(refresh)
    }
    function known(name) {
        return typeof name === "string" && Devices.printerName(name) && printers.some(p => p.name === name)
    }
    function usable(name) {
        return known(name) && !printers.find(p => p.name === name).announced
    }
    // The queue read again right before an action: its own first line
    function confirm(name, then) {
        checkJob.run(["lpstat", "-p", name], 8000, (code, out) => {
            if (code === 0 && Devices.parsePrinterState(out, name) !== "unknown")
                then()
            else {
                notice("A impressora não está mais disponível")
                refresh()
            }
        })
    }

    // ── Actions ──
    function setDefault(name) {
        if (!usable(name))
            return
        confirm(name, () => actJob.run(["lpoptions", "-d", name], 8000, code => {
            if (code !== 0)
                notice("Não deu para escolher a impressora padrão")
            refresh()
        }))
    }
    function cancel(id) {
        const job = jobs.find(j => j.id === id)
        if (!job || !job.mine || !known(job.printer) || !Number.isInteger(job.number) || job.number <= 0)
            return
        confirm(job.printer, () => actJob.run(["cancel", String(job.number)], 8000, code => {
            if (code !== 0)
                notice("Não deu para cancelar a impressão")
            refresh()
        }))
    }
    function testPage(name) {
        if (!usable(name))
            return
        confirm(name, () => actJob.run(["lp", "-d", name, "-t", "Página de teste", "--", testFile], 15000, code => {
            notice(code === 0 ? "Página de teste enviada" : "Não deu para enviar a página de teste")
            refresh()
        }))
    }
    function addPrinter() {
        Quickshell.execDetached(["system-config-printer"])
    }

    // ── Network discovery (avahi) ──
    readonly property var avahiUnits: ["avahi-daemon.socket", "avahi-daemon.service"]
    function readDiscovery() {
        // is-active exits non-zero when a unit is inactive; the lines count.
        // No answer at all (a read still running): the state stays as it was
        avahiStateJob.run(["systemctl", "is-active"].concat(avahiUnits), 5000, (code, out) => {
            const lines = String(out).split("\n").map(l => l.trim()).filter(l => l !== "")
            if (lines.length > 0)
                discovery = lines.includes("active")
        })
    }
    // On: the socket and the service started; off: both stopped (the socket
    // first in the list, so it cannot start the daemon again in between).
    // Never enable: it stays off after the next boot
    function setDiscovery(on) {
        if (discoveryBusy)
            return
        discoveryBusy = true
        discoveryJob.run(["systemctl", on ? "start" : "stop"].concat(avahiUnits), 120000, code => {
            discoveryBusy = false
            if (code !== 0)
                notice(on ? "Não deu para ligar a busca na rede" : "Não deu para desligar a busca na rede")
            readDiscovery()
        })
    }

    // A command with a time limit and LC_ALL=C: done(code, stdout), once.
    // Only a normal exit counts; past the limit it is stopped and counts as
    // failed; one still running (maybe stuck) is never started again: the
    // answer is a failure at once
    component Job: Process {
        id: job
        property var done: null
        property int code: -1
        property bool gotExit: false
        property bool gotOut: false
        property bool timedOut: false
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            id: jobOut
            onStreamFinished: {
                job.gotOut = true
                job.settle()
            }
        }
        function run(cmd, ms, cb) {
            if (running) {
                Qt.callLater(() => cb(-1, ""))
                return
            }
            done = cb
            code = -1
            gotExit = false
            gotOut = false
            timedOut = false
            // Through sh: printer names and job ids are outside data, and a
            // program that fails to start has its argv logged by Quickshell;
            // sh says only the program's name then
            command = ["sh", "-c", 'exec "$@"', "sh"].concat(cmd)
            limit.interval = ms
            limit.restart()
            running = true
        }
        function settle() {
            if (!gotExit || !gotOut || done === null)
                return
            const cb = done
            done = null
            limit.stop()
            cb(timedOut ? -1 : code, jobOut.text)
        }
        onExited: (exitCode, exitStatus) => {
            code = exitStatus === 0 ? exitCode : -1
            gotExit = true
            settle()
            if (done !== null)
                outWait.restart()
        }
        onRunningChanged: {
            if (!running && !gotExit)
                Qt.callLater(() => {
                    if (!job.gotExit && job.done !== null) {
                        job.gotExit = true
                        job.gotOut = true
                        job.code = -1
                        job.settle()
                    }
                })
        }
        property Timer outWait: Timer {
            interval: 1000
            onTriggered: {
                job.gotOut = true
                job.settle()
            }
        }
        property Timer limit: Timer {
            onTriggered: {
                job.timedOut = true
                job.running = false
                job.gotExit = true
                job.gotOut = true
                job.settle()
            }
        }
    }
    Job { id: readJob }
    Job { id: actJob }
    Job { id: checkJob }
    Job { id: discoveryJob }
    Job { id: avahiStateJob }
}
