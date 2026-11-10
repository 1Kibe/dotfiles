import QtQuick
import qs.theme

// A number between `from` and `to` on `step`, its value written beside it.
// Like the toggle, it only sends `moved`; the stored value comes back by
// binding (and snaps back if the store refuses it)
Item {
    id: root

    property real from: 0
    property real to: 1
    property real step: 1
    property real value: 0
    property string suffix: ""
    signal moved(real value)

    readonly property real fraction: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property int decimals: step >= 1 ? 0 : Math.ceil(-Math.log10(step) - 1e-9)

    function snap(f) {
        const v = from + Math.round(Math.max(0, Math.min(1, f)) * (to - from) / step) * step
        return Number(v.toFixed(decimals))
    }

    implicitWidth: 190
    implicitHeight: 24

    Item {
        id: lane
        anchors.left: parent.left
        anchors.right: number.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 16

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.bg2
            Rectangle {
                width: parent.width * root.fraction
                height: parent.height
                radius: parent.radius
                color: Theme.accentLight
            }
        }
        Rectangle {
            width: 12
            height: 12
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: (lane.width - width) * root.fraction
            color: Theme.text
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function at(mx) {
                const v = root.snap(mx / width)
                if (v !== root.value)
                    root.moved(v)
            }
            onPressed: mouse => at(mouse.x)
            onPositionChanged: mouse => { if (pressed) at(mouse.x) }
        }
    }
    Text {
        id: number
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        horizontalAlignment: Text.AlignRight
        text: `${root.value.toFixed(root.decimals).replace(".", ",")}${root.suffix}`
        color: Theme.fg4
        font.family: Theme.monoFont
        font.pointSize: Theme.fontSize - 1
    }
}
