import QtQuick
import QtQuick.Layouts
import qs.theme

// One of the bar's three areas (Bar.qml): a row of items, centered on the
// bar's height, built from their ids by the bar (frame.itemComponent)
RowLayout {
    id: root

    required property var frame
    property var ids: []

    spacing: Theme.spacing

    Repeater {
        model: root.ids
        Loader {
            required property string modelData
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: root.frame.itemComponent(modelData)
        }
    }
}
