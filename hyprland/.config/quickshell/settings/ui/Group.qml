import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// A group of a settings page: its title above, the rows in one rounded block
// (the rows draw the thin lines between them). "Restaurar padrão", at the
// right of the title, shows only while a key of `keys` differs from the
// default, and puts them all back in one change. `columns` titles the two
// controls of paired rows ({ icon, label } each). `flash()` lights the block
// for a moment (a search result); `motion` plays its part of the page's
// cascade.
ColumnLayout {
    id: root

    property string title
    property var keys: []
    property var columns: []
    default property alias rows: block.data

    spacing: 6

    readonly property var changedKeys: SettingsStore.ready
        ? keys.filter(k => JSON.stringify(SettingsStore.values[k]) !== JSON.stringify(SettingsStore.defaults[k])) : []

    // Its place in the page's cascade (CascadeMotion)
    transform: Translate { id: shift }
    readonly property alias motion: motionItem
    CascadeMotion {
        id: motionItem
        target: root
        translate: shift
    }

    property real glow: 0
    function flash() {
        glowAnim.restart()
    }
    SequentialAnimation {
        id: glowAnim
        NumberAnimation { target: root; property: "glow"; to: 0.9; duration: Theme.dur(Theme.searchFlash / 4) }
        NumberAnimation { target: root; property: "glow"; to: 0; duration: Theme.dur(Theme.searchFlash * 3 / 4); easing.type: Easing.InOutSine }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.fg4
            wrapMode: Text.WordWrap
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
            font.bold: true
        }
        // The two columns of paired rows
        Repeater {
            model: root.columns
            Text {
                required property var modelData
                Layout.preferredWidth: 150
                horizontalAlignment: Text.AlignHCenter
                text: modelData.icon ? `${modelData.icon}  ${modelData.label}` : modelData.label
                color: Theme.gray
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 2
            }
        }
        Text {
            id: restore
            text: "Restaurar padrão"
            color: restoreMouse.containsMouse ? Theme.accentLight : Theme.gray
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 2
            font.underline: restoreMouse.containsMouse
            opacity: root.changedKeys.length > 0 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.dur(Theme.animFast) }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.dur(Theme.animFast) }
            }
            MouseArea {
                id: restoreMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.resetMany(root.changedKeys)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: block.implicitHeight + 4
        radius: Theme.radius
        color: Theme.veil
        border.width: 1
        border.color: Theme.alpha(Theme.accentLight, root.glow)

        ColumnLayout {
            id: block
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 2
            spacing: 0
        }
    }
}
