import QtQuick
import QtQuick.Layouts
import qs.theme

// A block of rows (ListRow) in the sections' lists, the same in all of
// them: the dark fill and the Theme's corners, the rows one under the
// other with no gap (each draws its thin line above), scrolling inside
// past maxHeight.
Rectangle {
    id: root

    // > 0: the most it takes before scrolling inside
    property real maxHeight: 0
    default property alias content: column.data

    // Scrolls so that an item of the block (a row the keyboard went to)
    // shows whole
    function reveal(item) {
        if (!item)
            return
        const y = item.mapToItem(column, 0, 0).y
        if (y < flick.contentY)
            flick.contentY = y
        else if (y + item.height > flick.contentY + flick.height)
            flick.contentY = y + item.height - flick.height
    }

    Layout.fillWidth: true
    implicitHeight: flick.height
    radius: Theme.radius
    color: Theme.bg

    Flickable {
        id: flick
        width: parent.width
        height: root.maxHeight > 0 ? Math.min(column.implicitHeight, root.maxHeight) : column.implicitHeight
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: column.implicitHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column
            width: flick.width
            spacing: 0
        }
    }
}
