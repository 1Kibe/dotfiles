import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state

// Power menu that drops down from the power button: log out, suspend,
// reboot, power off. Reboot and power off need a second click.
// Esc or a click outside closes it.
PopupWindow {
    id: root

    required property Item button
    property string armed: ""   // action waiting for its second click

    readonly property var actions: [
        { id: "logout", icon: "󰍃", label: "Sair", confirm: false,
          command: ["sh", "-c", "uwsm check is-active && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"] },
        { id: "suspend", icon: "󰤄", label: "Suspender", confirm: false, command: ["systemctl", "suspend"] },
        { id: "reboot", icon: "󰜉", label: "Reiniciar", confirm: true, command: ["systemctl", "reboot"] },
        { id: "poweroff", icon: "󰐥", label: "Desligar", confirm: true, command: ["systemctl", "poweroff"] }
    ]

    function close() {
        ShellState.powerMenuOn = ""
    }

    function run(action) {
        if (action.confirm && armed !== action.id) {
            armed = action.id
            return
        }
        close()
        Quickshell.execDetached(action.command)
    }

    anchor.item: button
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 8
    grabFocus: true
    color: Theme.clear
    implicitWidth: 290
    implicitHeight: list.implicitHeight + 12

    onVisibleChanged: {
        armed = ""
        if (!visible)
            close()   // dismissed by a click outside
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.barFill
    }

    ColumnLayout {
        id: list

        anchors.fill: parent
        anchors.margins: 6
        spacing: 2
        focus: true
        Keys.onEscapePressed: root.close()

        Repeater {
            model: root.actions

            Rectangle {
                id: row

                required property var modelData
                readonly property bool isArmed: root.armed === modelData.id

                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.radius
                color: isArmed ? Theme.danger : mouse.containsMouse ? Theme.veil : Theme.clear

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: row.modelData.icon
                        color: row.isArmed ? Theme.red : Theme.text
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.isArmed ? `Clique de novo para ${row.modelData.label.toLowerCase()}` : row.modelData.label
                        color: row.isArmed ? Theme.red : Theme.text
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run(row.modelData)
                }
            }
        }
    }
}
