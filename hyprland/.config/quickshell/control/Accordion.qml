import QtQuick
import QtQuick.Layouts
import qs.theme

// A section of the control center that folds out under the grid: its height
// grows from 0 to its content in Theme.animNormal, never past maxHeight (the
// content scrolls inside past that). With reduce motion the height changes
// at once and the content only fades. ShellState.controlSection says which
// one is open, so opening one folds the other in the same movement.
Item {
    id: root

    property bool open: false
    property real maxHeight: 400
    default property alias content: column.data
    readonly property real fullHeight: Math.min(column.implicitHeight, maxHeight)

    Layout.fillWidth: true
    implicitHeight: open ? fullHeight : 0
    Behavior on implicitHeight {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
    }
    opacity: open ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Theme.dur(Theme.animFast) }
    }
    visible: implicitHeight > 0
    clip: true

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: column.implicitHeight > root.maxHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 2
        }
    }
}
