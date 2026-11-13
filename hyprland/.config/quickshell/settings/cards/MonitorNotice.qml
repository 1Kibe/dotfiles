import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// The top of Configurações → Monitores: local.lua (this machine's own
// Hyprland lines, loaded last) also sets screens, so it wins over the page.
// Read by MonitorsApply (text only). Nothing to say: `empty`, the strip
// hides.
Rectangle {
    id: root

    readonly property bool empty: !MonitorsApply.localLuaHasMonitors

    implicitHeight: row.implicitHeight + 16
    radius: Theme.radius
    color: Theme.alpha(Theme.yellow, 0.12)

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        Text {
            Layout.alignment: Qt.AlignTop
            text: "󰀦"
            color: Theme.yellow
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        Text {
            Layout.fillWidth: true
            text: "O local.lua desta máquina também configura telas e vale por cima desta página."
            textFormat: Text.PlainText
            color: Theme.text
            wrapMode: Text.WordWrap
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
    }
}
