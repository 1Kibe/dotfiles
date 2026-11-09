import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// While the screen is being recorded: a red dot, the time (mm:ss), a mic
// when the microphone is in it, and a stop button. A click stops. Only
// there during a recording; fades in and out.
Rectangle {
    id: root

    readonly property bool shown: CaptureState.recording

    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    implicitWidth: row.implicitWidth + 16
    implicitHeight: Theme.itemHeight
    radius: height / 2
    color: Theme.danger

    function two(n) {
        return n < 10 ? `0${n}` : `${n}`
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: Theme.red
        }
        Text {
            text: `${root.two(Math.floor(CaptureState.elapsed / 60))}:${root.two(CaptureState.elapsed % 60)}`
            color: Theme.text
            font.family: Theme.monoFont
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            visible: CaptureState.micOn
            text: "󰍬"
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            text: "󰓛"
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: CaptureState.stopRecord()
    }
}
