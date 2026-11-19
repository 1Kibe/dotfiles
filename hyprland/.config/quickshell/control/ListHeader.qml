import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.bar

// The header of every section of the control center and of the groups
// inside them ("Pareados", "Apps"…), the same in all of them: the icon
// (a section's) and the name, dim, on the left; on the right the state or
// the count, dim, then anything in `trailing`, then the switch when the
// section has one. The words here are the shell's own.
RowLayout {
    id: root

    property string icon
    property string title
    property string detail
    // A section's header (taller, the switch's room) or a group's label
    property bool section: false
    property bool hasSwitch: false
    property bool checked: false
    // The keyboard is on the switch (a ring of the Theme)
    property bool switchFocus: false
    default property alias trailing: trail.data
    signal toggled()

    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    Layout.topMargin: section ? 0 : 6
    Layout.minimumHeight: section ? Theme.listRowHeight : 0
    spacing: 6

    Text {
        visible: root.icon !== ""
        text: root.icon
        textFormat: Text.PlainText
        color: Theme.fg4
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }
    Text {
        Layout.fillWidth: true
        text: root.title
        textFormat: Text.PlainText
        maximumLineCount: 1
        elide: Text.ElideRight
        color: Theme.fg4
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
        font.weight: Font.Medium
    }
    Text {
        visible: root.detail !== ""
        text: root.detail
        textFormat: Text.PlainText
        maximumLineCount: 1
        elide: Text.ElideRight
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSizeSmall
    }
    RowLayout {
        id: trail
        spacing: 4
    }
    PanelSwitch {
        visible: root.hasSwitch
        Layout.leftMargin: 2
        checked: root.checked
        onToggled: root.toggled()

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.radius
            color: Theme.clear
            visible: root.switchFocus
            border.width: Theme.focusWidth
            border.color: Theme.focusRing
        }
    }
}
