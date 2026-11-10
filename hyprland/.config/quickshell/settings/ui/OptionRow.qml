import QtQuick
import QtQuick.Layouts
import qs.theme

// One option: its label (and a short description under it) on the left,
// the control on the right
RowLayout {
    id: root

    property string label
    property string desc
    default property alias control: slot.data

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Text {
            Layout.fillWidth: true
            text: root.label
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.desc
            color: Theme.gray
            elide: Text.ElideRight
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 2
        }
    }
    Item {
        id: slot
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
