import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// CPU, memory and CPU temperature as three small rings with the number at
// their side; yellow and red under load. No CPU sensor (VMs): no
// temperature ring. Click (or Ctrl+Shift+Esc) opens the system panel.
Item {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    readonly property string monitorName: monitor ? monitor.name : ""
    // From ShellState; the click and the keybind (shell.qml) toggle the same panel
    readonly property bool open: ShellState.isOpen("system", monitorName)

    // Same 6 px side padding as a BarItem
    implicitWidth: row.implicitWidth + 12
    implicitHeight: Theme.itemHeight

    // Same hover veil and spring as BarItem, rebuilt here because this
    // holds rings instead of a single label
    scale: mouse.pressed ? 0.96 : mouse.containsMouse ? 1.04 : 1
    Behavior on scale {
        SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.005 }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: mouse.containsMouse ? Theme.veil : Theme.clear
    }

    // Widest number, so the bar does not shift as values change
    TextMetrics {
        id: widest
        font.family: Theme.font
        font.pointSize: Theme.fontSize
        text: "100%"
    }

    // One ring and its number. warn/crit are where it turns yellow and red
    // (Theme.loadColor).
    component Gauge: RowLayout {
        id: gauge

        required property real value      // 0 to 100 (°C for the temperature)
        required property string icon
        required property string label
        property int warn: Theme.usageWarn
        property int crit: Theme.usageCrit

        spacing: 4

        Ring {
            // Ring takes 0 to 1: the temperature ring is full at 100 °C
            value: gauge.value / 100
            color: Theme.loadColor(gauge.value, gauge.warn, gauge.crit)
            text: gauge.icon
        }
        Text {
            Layout.preferredWidth: widest.width
            text: gauge.label
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        // SystemStats reads /proc and the CPU sensor every 2 s
        Gauge {
            value: SystemStats.cpu
            icon: "󰍛"
            label: `${Math.round(SystemStats.cpu)}%`
        }
        Gauge {
            value: SystemStats.memPercent
            icon: "󰘚"
            label: `${Math.round(SystemStats.memPercent)}%`
        }
        Gauge {
            visible: SystemStats.hasTemp
            value: SystemStats.temp
            icon: "󰔏"
            label: `${Math.round(SystemStats.temp)}°`
            // Its own thresholds, in °C
            warn: Theme.tempWarn
            crit: Theme.tempCrit
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggle("system", root.monitorName)
    }

    // The exact numbers, with memory as used of total; not while the panel is open
    Tooltip {
        target: root
        shown: mouse.containsMouse && !mouse.pressed && !root.open
        text: {
            let t = `CPU ${Math.round(SystemStats.cpu)}% · Memória ${SystemStats.memText(SystemStats.memUsed)} de ${SystemStats.memText(SystemStats.memTotal)}`
            if (SystemStats.hasTemp)
                t += ` · ${Math.round(SystemStats.temp)} °C`
            return t
        }
    }

    // A child of the button so it anchors under it
    SystemPanel {
        button: root
        open: root.open
    }
}
