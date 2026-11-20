import QtQuick
import qs.theme
import qs.state

// The clipboard drawer's body (ClipboardDrawer): the fill with square
// corners and the thin line on top, and the tabs (ClipStrip). progress: 0
// = down out of its window, 1 = in place; reduce motion fades instead.
// `hit` is the part on the screen, the only part that takes clicks.
Item {
    id: root

    property real progress: 0
    readonly property real drop: Theme.reduceMotion ? 0 : Math.round(height * (1 - progress))
    readonly property Item hit: hitArea
    readonly property alias strip: strip
    readonly property alias fill: fillRect

    Item {
        id: hitArea
        y: root.drop
        width: root.width
        height: Math.max(0, root.height - root.drop)
    }

    Item {
        id: body
        y: root.drop
        width: root.width
        height: root.height
        opacity: Theme.reduceMotion ? root.progress : 1

        // Square corners: the drawer meets the screen's edges
        Rectangle {
            id: fillRect
            anchors.fill: parent
            radius: 0
            color: Theme.clipboardFill
        }
        // The thin line on top only
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg1
        }

        ClipStrip {
            id: strip
            anchors.fill: parent
            anchors.topMargin: 1
        }
    }
}
