pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// CPU, memory and CPU temperature for the bar, read from /proc and /sys
// every 2 s (FileView, no process per tick). The process list is read only
// while the system panel is open. Panels: bar/SystemStatus, bar/SystemPanel.
Singleton {
    id: root

    property real cpu: 0          // percent of the whole machine
    property int cores: 0
    property real memUsed: 0      // kB (MemTotal - MemAvailable)
    property real memTotal: 0     // kB
    readonly property real memPercent: memTotal > 0 ? memUsed / memTotal * 100 : 0
    property real uptime: 0       // seconds
    property string tempPath: ""  // CPU sensor; "" = none (e.g. a VM)
    readonly property bool hasTemp: tempPath !== ""
    property real temp: 0         // °C

    // Process list, top first: { pid, name, cpu (% of the machine), mem (kB), killable }
    property var processes: []
    property int processCount: 0
    property bool processesReady: false   // the list has CPU numbers (two reads done)
    readonly property bool watching: ShellState.openPanel === "system"

    // Never offered for "end process": the session itself and its sound
    readonly property var protectedNames: /^(qs|quickshell|Hyprland|hyprland|Xwayland|uwsm.*|pipewire.*|wireplumber|systemd.*)$/

    property var lastCpu: null        // { total, idle } of the previous /proc/stat read
    property var lastTicks: ({})      // pid -> utime + stime of the previous list read
    property real lastTotal: 0        // all-CPU jiffies at that read

    function sumFields(fields) {
        // user nice system idle iowait irq softirq steal (guest is inside user)
        let total = 0
        for (let i = 0; i < 8 && i < fields.length; i++)
            total += Number(fields[i])
        return total
    }

    function cpuLine(text) {
        const line = text.split("\n")[0]
        return line.startsWith("cpu ") ? line.trim().split(/\s+/).slice(1) : []
    }

    function readCpu(text) {
        cores = (text.match(/^cpu\d+ /gm) || []).length
        const f = cpuLine(text)
        if (f.length < 5)
            return
        const total = sumFields(f)
        const idle = Number(f[3]) + Number(f[4])
        if (lastCpu && total > lastCpu.total)
            cpu = Math.max(0, Math.min(100, (1 - (idle - lastCpu.idle) / (total - lastCpu.total)) * 100))
        lastCpu = { total: total, idle: idle }
    }

    function readMem(text) {
        const total = text.match(/^MemTotal:\s+(\d+)/m)
        const avail = text.match(/^MemAvailable:\s+(\d+)/m)
        if (total && avail) {
            memTotal = Number(total[1])
            memUsed = memTotal - Number(avail[1])
        }
    }

    // Output of the list command: /proc/stat, "@", every /proc/<pid>/stat,
    // "@", the pids of this user
    function readProcesses(text) {
        const parts = text.split("\n@\n")
        if (!watching || parts.length < 3)
            return
        const total = sumFields(cpuLine(parts[0]))
        const own = new Set(parts[2].trim().split(/\s+/))
        const span = total - lastTotal
        const ticks = {}
        const list = []
        for (const line of parts[1].split("\n")) {
            // pid (name) state ...: the name may hold spaces and parentheses
            const open = line.indexOf(" (")
            const close = line.lastIndexOf(")")
            if (open < 0 || close < open)
                continue
            const pid = line.slice(0, open)
            const name = line.slice(open + 2, close)
            const f = line.slice(close + 2).split(" ")
            const used = Number(f[11]) + Number(f[12])   // utime + stime
            const rss = Number(f[21]) * 4                 // pages of 4 kB
            ticks[pid] = used
            if (rss === 0)
                continue   // kernel threads
            const before = lastTicks[pid]
            list.push({
                pid: Number(pid),
                name: name,
                cpu: before !== undefined && span > 0 ? Math.max(0, (used - before) / span * 100) : 0,
                mem: rss,
                killable: own.has(pid) && !protectedNames.test(name)
            })
        }
        processesReady = Object.keys(lastTicks).length > 0
        lastTicks = ticks
        lastTotal = total
        processCount = Object.keys(ticks).length
        processes = list
    }

    // "245 MB", "1,6 GB" (kB in)
    function memText(kb) {
        const mb = kb / 1024
        if (mb < 1000)
            return `${Math.round(mb)} MB`
        return `${(mb / 1024).toLocaleString(Theme.locale, "f", 1)} GB`
    }

    // "3,2%" below 10, "12%" above
    function percentText(v) {
        return v < 10 ? `${v.toLocaleString(Theme.locale, "f", 1)}%` : `${Math.round(v)}%`
    }

    // "2h 13m", "3d 4h", "12m"
    function uptimeText(s) {
        const d = Math.floor(s / 86400)
        const h = Math.floor(s % 86400 / 3600)
        const m = Math.floor(s % 3600 / 60)
        return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`
    }

    function endProcess(pid) {
        const p = processes.find(x => x.pid === pid)
        if (p && p.killable)
            Quickshell.execDetached(["kill", "-TERM", String(pid)])
    }

    function refreshProcesses() {
        if (watching && !list.running)
            list.running = true
    }

    // Opening the panel: fresh list now and a second read soon after, so the
    // CPU column is not empty for the first 2 s
    onWatchingChanged: {
        if (watching) {
            lastTicks = {}
            processesReady = false
            refreshProcesses()
            quickSecond.restart()
        } else {
            processes = []
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload()
            meminfo.reload()
            uptimeFile.reload()
            if (root.hasTemp)
                tempFile.reload()
            root.refreshProcesses()
        }
    }

    Timer {
        id: quickSecond
        interval: 600
        onTriggered: root.refreshProcesses()
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: root.readCpu(text())
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: root.readMem(text())
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0]) || 0
    }

    FileView {
        id: tempFile
        path: root.tempPath
        onLoaded: root.temp = Number(text().trim()) / 1000
    }

    // One cat for the whole list, only while the panel is open
    Process {
        id: list
        command: ["sh", "-c", "cat /proc/stat; echo @; cat /proc/[0-9]*/stat 2>/dev/null; echo; echo @; "
                  + "find /proc -mindepth 1 -maxdepth 1 -user \"$(id -u)\" -name '[0-9]*' -printf '%f '"]
        stdout: StdioCollector {
            onStreamFinished: root.readProcesses(text)
        }
    }

    // CPU sensor, looked up once: Intel package, AMD Tctl, or the x86
    // package thermal zone. Disks (nvme) and others are not the CPU.
    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
              case "$(cat "$h/name" 2>/dev/null)" in
                coretemp) want="Package id 0" ;;
                k10temp)  want="Tctl" ;;
                *) continue ;;
              esac
              for l in "$h"/temp*_label; do
                if [ "$(cat "$l" 2>/dev/null)" = "$want" ]; then echo "\${l%_label}_input"; exit; fi
              done
            done
            for z in /sys/class/thermal/thermal_zone*; do
              if [ "$(cat "$z/type" 2>/dev/null)" = x86_pkg_temp ]; then echo "$z/temp"; exit; fi
            done`]
        stdout: StdioCollector {
            onStreamFinished: root.tempPath = text.trim()
        }
    }
}
