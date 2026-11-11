import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state

// System panel, under the bar's rings: big rings for CPU, memory and
// temperature, uptime, and the processes using the most CPU or memory
// (instant CPU, refreshed every 2 s while open). ✕ on a process of this
// user arms "end process"; a second click sends SIGTERM. Footer opens btop.
AttachedPanel {
    id: root

    property string sortBy: "cpu"      // "cpu" or "mem"
    // A copy picked from SystemStats.processes by pickRows(), not a binding,
    // so the order can be held still while the mouse is over the list
    property var rows: []              // processes on screen
    property int armedPid: -1          // process waiting for its second click
    property bool frozenReady: false   // rows on screen already sorted with CPU numbers
    readonly property int maxRows: 8

    // The rings sit on the left of the bar: grow right from them
    alignLeft: true
    panelWidth: 360

    // Reset on opening only: closing keeps the rows while it fades out
    onOpenChanged: {
        if (open) {
            armedPid = -1
            rows = []
            frozenReady = false
        }
    }
    // A tab change re-sorts at once, even under the mouse
    onSortByChanged: pickRows(true)

    // SystemStats reads the processes every 2 s only while this panel is
    // open (its `watching`); each new list refreshes the rows
    Connections {
        target: SystemStats
        function onProcessesChanged() {
            if (root.open)
                root.pickRows()
        }
    }

    // Top processes. While the mouse is over the list the order stays put
    // (numbers still update), so a row does not move under the pointer;
    // not before the first CPU numbers, and not after a tab change.
    function pickRows(resort) {
        const key = sortBy
        // Ties (often 0% CPU) fall back to memory, so the order is stable
        const sorted = SystemStats.processes.slice().sort((a, b) => b[key] - a[key] || b.mem - a.mem)
        let picked
        // Frozen: the same pids in the same order with fresh numbers; ended
        // processes drop out and the free slots fill from the top of the sort
        if (listHover.hovered && rows.length > 0 && !resort && frozenReady) {
            const byPid = {}
            for (const p of sorted)
                byPid[p.pid] = p
            picked = rows.map(r => byPid[r.pid]).filter(p => p !== undefined)
            for (const p of sorted) {
                if (picked.length >= maxRows)
                    break
                if (!picked.some(x => x.pid === p.pid))
                    picked.push(p)
            }
        } else {
            picked = sorted.slice(0, maxRows)
        }
        rows = picked
        // The first list has 0% CPU everywhere (one read only): never freeze
        // that order. An armed process that left the list is disarmed.
        frozenReady = SystemStats.processesReady
        if (armedPid !== -1 && !rows.some(r => r.pid === armedPid))
            armedPid = -1
    }

    // Two clicks: the first arms the row (red, "Clique de novo"), the second
    // on the same pid sends SIGTERM. SystemStats checks `killable` again.
    function end(proc) {
        if (armedPid !== proc.pid) {
            armedPid = proc.pid
            return
        }
        armedPid = -1
        SystemStats.endProcess(proc.pid)
    }

    // A big ring with a title and a detail line. value is 0-100; warn and
    // crit pick the ring color (temperature passes its own limits).
    component BigGauge: ColumnLayout {
        id: gauge

        required property real value
        required property string center
        required property string title
        required property string detail
        property int warn: Theme.usageWarn
        property int crit: Theme.usageCrit

        spacing: 2

        Ring {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
            implicitWidth: Theme.ringBigSize
            thickness: 5
            value: gauge.value / 100
            color: Theme.loadColor(gauge.value, gauge.warn, gauge.crit)
            text: gauge.center
            textSize: 15
            bold: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: gauge.title
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: gauge.detail
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
    }

    // Sort tab, a pill: tinted accent when active, veil on hover
    component Tab: Rectangle {
        id: tab

        required property string label
        required property string key
        readonly property bool active: root.sortBy === key

        // 10 px of padding on each side of the label
        implicitWidth: tabText.implicitWidth + 20
        implicitHeight: 24
        radius: height / 2
        color: active ? Theme.alpha(Theme.accentLight, 0.22) : tabMouse.containsMouse ? Theme.veil : Theme.clear
        Behavior on color {
            ColorAnimation { duration: Theme.animFast }
        }

        Text {
            id: tabText
            anchors.centerIn: parent
            text: tab.label
            color: tab.active ? Theme.text : Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sortBy = tab.key
        }
    }

    // Numbers on the right of the list, same width on every row
    component Cell: Text {
        Layout.preferredWidth: 58
        horizontalAlignment: Text.AlignRight
        color: Theme.text
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        spacing: 28

        BigGauge {
            value: SystemStats.cpu
            center: `${Math.round(SystemStats.cpu)}%`
            title: "CPU"
            detail: `${SystemStats.cores} núcleos`
        }
        BigGauge {
            value: SystemStats.memPercent
            center: `${Math.round(SystemStats.memPercent)}%`
            title: "Memória"
            detail: `${SystemStats.memText(SystemStats.memUsed)} / ${SystemStats.memText(SystemStats.memTotal)}`
        }
        // Hidden where no sensor is found (a VM usually has none)
        BigGauge {
            visible: SystemStats.hasTemp
            value: SystemStats.temp
            center: `${Math.round(SystemStats.temp)}°`
            title: "Temperatura"
            detail: SystemStats.temp >= Theme.tempCrit ? "muito quente" : SystemStats.temp >= Theme.tempWarn ? "quente" : "normal"
            warn: Theme.tempWarn
            crit: Theme.tempCrit
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        Layout.bottomMargin: 6
        text: `up ${SystemStats.uptimeText(SystemStats.uptime)} · ${SystemStats.processCount} processos`
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    // Tabs on the left, column headers on the right. Same margins and cell
    // widths as the rows below, so the headers sit over their numbers.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 12
        Layout.bottomMargin: 2
        spacing: 4

        Tab {
            label: "Por CPU"
            key: "cpu"
        }
        Tab {
            label: "Por memória"
            key: "mem"
        }
        Item {
            Layout.fillWidth: true
        }
        Cell {
            text: "CPU"
            color: Theme.gray
            font.pointSize: Theme.fontSize - 1
        }
        Cell {
            text: "Memória"
            color: Theme.gray
            font.pointSize: Theme.fontSize - 1
        }
        Item {
            implicitWidth: 22   // over the ✕ column
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        // Read by pickRows() to hold the order; a HoverHandler sees the
        // pointer even over the rows' own MouseAreas
        HoverHandler {
            id: listHover
        }

        Text {
            visible: root.rows.length === 0
            Layout.leftMargin: 12
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            text: "Lendo os processos…"
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }

        Repeater {
            // Fixed rows that change their data in place: the hover stays put
            model: root.maxRows

            Rectangle {
                id: line

                required property int index
                readonly property var proc: index < root.rows.length ? root.rows[index] : null
                readonly property bool armed: proc !== null && root.armedPid === proc.pid

                // Fewer processes than maxRows: the spare rows just hide
                visible: proc !== null
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radius
                color: armed ? Theme.danger : lineMouse.containsMouse ? Theme.veil : Theme.clear
                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                // Hover only (veil and showing the ✕); the row has no click
                MouseArea {
                    id: lineMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 4
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: line.armed ? "Clique de novo para encerrar" : line.proc ? line.proc.name : ""
                        color: line.armed ? Theme.red : Theme.text
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize
                    }
                    // The column being sorted by is brighter
                    Cell {
                        text: line.proc ? SystemStats.percentText(line.proc.cpu) : ""
                        color: root.sortBy === "cpu" ? Theme.text : Theme.fg4
                    }
                    Cell {
                        text: line.proc ? SystemStats.memText(line.proc.mem) : ""
                        color: root.sortBy === "mem" ? Theme.text : Theme.fg4
                    }
                    // ✕: only for this user's processes (SystemStats `killable`),
                    // on hover or while armed. Faded with opacity, not hidden,
                    // so the column keeps its width and the numbers stay aligned.
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: Theme.radius
                        readonly property bool shown: line.proc !== null && line.proc.killable
                                                      && (lineMouse.containsMouse || closeMouse.containsMouse || line.armed)
                        opacity: shown ? 1 : 0
                        color: closeMouse.containsMouse ? Theme.danger : Theme.clear
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animFast }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: line.armed || closeMouse.containsMouse ? Theme.red : Theme.fg4
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            // An invisible ✕ must not take clicks
                            enabled: parent.shown
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.end(line.proc)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.bg2
    }

    PanelRow {
        icon: ""
        text: "Abrir o btop"
        onClicked: {
            ShellState.close()
            // Same command as the old Ctrl+Shift+Esc; floats by rules.lua
            Quickshell.execDetached(["kitty", "--class", "btop", "btop"])
        }
    }
}
