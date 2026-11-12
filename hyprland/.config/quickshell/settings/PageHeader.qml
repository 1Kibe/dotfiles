import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "ui"
import "schema.js" as Schema

// The top of a settings page: the group's name small, the page's title
// under it; on the right, "Salvo" for a moment after each real write of the
// settings file, the search over every page ("Buscar em tudo", its results
// open under it, over the page) and the close button.
Item {
    id: root

    property string page: "tema"
    readonly property var info: Schema.PAGES.find(p => p.id === page) || Schema.PAGES[0]
    signal searched(string page, string card)
    property alias search: search

    implicitHeight: 64
    z: 5

    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            text: root.info.group
            color: Theme.fg4
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
        }
        Text {
            text: root.info.name
            color: Theme.text
            font.family: Theme.fontPanels
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 16
        spacing: 10

        // "Salvo": the store wrote the file; it fades out on its own
        Text {
            id: saved
            text: "󰄬  Salvo"
            color: Theme.green
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
            opacity: savedTimer.running ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.dur(Theme.animNormal) }
            }
        }
        Timer {
            id: savedTimer
            interval: 1500
        }
        Connections {
            target: SettingsStore
            function onSaved() { savedTimer.restart() }
        }

        Search {
            id: search
            Layout.preferredWidth: 220
            Layout.alignment: Qt.AlignTop
            onChosen: (page, card) => root.searched(page, card)
        }

        // Close
        Rectangle {
            Layout.alignment: Qt.AlignTop
            width: 28
            height: 28
            radius: Theme.radius
            color: closeMouse.containsMouse ? Theme.veil : Theme.alpha(Theme.fg, 0)
            Behavior on color {
                ColorAnimation { duration: Theme.dur(Theme.animFast) }
            }
            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize + 1
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.close()
            }
        }
    }
}
