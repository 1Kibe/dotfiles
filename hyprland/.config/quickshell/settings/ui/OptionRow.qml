import QtQuick
import QtQuick.Layouts
import qs.theme

// One option of a group: its name (and a short description under it) on the
// left, the control on the right. The name wraps, never cut with "…". A
// value that differs from the default shows a dot in the accent color after
// the name, and the description says so with the default's value. Hover
// lights the row with the panels' veil (Theme.animFast); `divider` draws the
// thin line that separates it from the row above.
Item {
    id: root

    property string label
    property string desc
    // The value differs from the default; defaultText: the default, as it
    // reads (settings/format.js)
    property bool changed: false
    property string defaultText
    property bool divider: false
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 16

    // The label goes in as StyledText (for the dot): escaped
    function escapeText(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }
    readonly property string shownDesc: changed ? `Alterado · padrão ${defaultText}` : desc

    Rectangle {
        anchors.fill: parent
        radius: Math.max(0, Theme.radius - 2)
        color: hover.hovered ? Theme.veil : Theme.alpha(Theme.fg, 0)
        Behavior on color {
            ColorAnimation { duration: Theme.dur(Theme.animFast) }
        }
    }
    Rectangle {
        visible: root.divider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: Theme.bg1
    }
    HoverHandler {
        id: hover
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                id: name
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: root.escapeText(root.label)
                      + (root.changed ? `&nbsp;<font color="${Theme.accentLight}">●</font>` : "")
                color: Theme.text
                wrapMode: Text.WordWrap
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize
            }
            Text {
                id: description
                Layout.fillWidth: true
                visible: text !== ""
                text: root.shownDesc
                color: root.changed ? Theme.fg4 : Theme.gray
                wrapMode: Text.WordWrap
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 2
            }
        }
        Item {
            id: slot
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
