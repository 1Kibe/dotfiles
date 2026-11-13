import QtQuick
import QtQuick.Layouts
import qs.theme

// A line of a panel: icon, text and a detail on the right. Clickable rows
// get a light veil on hover; `danger` paints it red (armed action, error).
Rectangle {
    id: root

    property string icon
    property string text
    property string detail
    property bool clickable: true
    property bool danger: false
    // Read by NetworkPanel to show a row's extra buttons only on hover
    readonly property bool hovered: mouse.containsMouse
    default property alias trailing: trail.data   // extra buttons at the end

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 34
    radius: Theme.radius
    // danger wins over hover, so an armed row stays red under the pointer
    color: danger ? Theme.danger : clickable && mouse.containsMouse ? Theme.veil : Theme.clear
    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }

    // Declared before the RowLayout, so buttons in `trailing` sit on top of
    // it and get their own clicks
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.clickable)
                root.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Text {
            visible: root.icon !== ""
            textFormat: Text.PlainText
            text: root.icon
            color: root.danger ? Theme.red : Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        // Takes the free space and elides, so the detail and buttons stay whole
        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            maximumLineCount: 1
            text: root.text
            elide: Text.ElideRight
            color: root.danger ? Theme.red : Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        Text {
            visible: root.detail !== ""
            textFormat: Text.PlainText
            maximumLineCount: 1
            text: root.detail
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        RowLayout {
            id: trail
            spacing: 4
        }
    }
}
