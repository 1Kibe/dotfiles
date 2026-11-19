import QtQuick
import QtQuick.Layouts
import qs.theme

// A section of the control center that folds out: a card of its own (the
// grid buttons' fill and corners), a gap of the grid's spacing above it and
// the same padding inside. Its height grows from 0 to the card in
// Theme.animNormal, never past maxHeight (the content scrolls inside past
// that). With reduce motion the height changes at once and the content only
// fades. ShellState.controlSection says which one is open, so opening one
// folds the other in the same movement.
Item {
    id: root

    property bool open: false
    property real maxHeight: 400
    default property alias content: column.data
    // The gap above the card and the padding inside it
    readonly property real pad: Theme.tileGap
    // The whole height (gap, card, padding), never past maxHeight
    readonly property real fullHeight: Math.min(pad + column.implicitHeight + 2 * pad, maxHeight)

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

    Rectangle {
        id: card
        x: 4
        y: root.pad
        width: root.width - 8
        height: root.fullHeight - root.pad
        radius: Theme.radius
        color: Theme.tileFill

        Flickable {
            anchors.fill: parent
            anchors.margins: root.pad
            contentWidth: width
            contentHeight: column.implicitHeight
            interactive: column.implicitHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: column
                width: parent.width
                spacing: 2
            }
        }
    }
}
