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
    readonly property bool open: ShellState.isOpen("system", monitorName)

    implicitWidth: row.implicitWidth + 12
    implicitHeight: Theme.itemHeight

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

    component Gauge: RowLayout {
        id: gauge

        required property real value      // 0 to 100 (°C for the temperature)
        required property string icon
        required property string label
        property int warn: Theme.usageWarn
        property int crit: Theme.usageCrit

        spacing: 4

        Ring {
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

    SystemPanel {
        button: root
        open: root.open
    }
}
