import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state

// While the screen is being recorded: a red dot, the time (mm:ss), a mic
// when the microphone is in it, and a stop button. A click stops. Only
// there during a recording; fades in and out.
Rectangle {
    id: root

    // Set by CaptureState while gpu-screen-recorder runs
    readonly property bool shown: CaptureState.recording

    // Stays in the bar until the fade-out ends, then takes no space
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // 8 px on each side; a radius of half the height makes the pill shape
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
        // elapsed is whole seconds, counted by CaptureState; the mono font keeps
        // the digits from shifting the pill every second
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
        // Stop icon only: the whole pill is the button (MouseArea below)
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
