import QtQuick
import QtQuick.Layouts
import qs.theme

// One row of the sections' lists, the same in all of them: a dot or an
// icon (a glyph, or a theme image), the name on the left (it gives way
// first), a note beside it, dim, and on the right the value or the action,
// dim (mono for addresses and versions), then anything in `trailing`.
// Inside a block (ListBlock) a thin line above it (divider) parts it from
// the row before. Clickable rows get the veil on hover; `danger` turns it
// red (an armed action); `action` is a row that does something ("Mais
// opções…", "e mais N"), in the dim colour. Text shows as plain text.
Item {
    id: root

    property string icon
    property color iconColor: Theme.fg4
    // A resolved icon path (an app's, from the icon theme); the glyph in
    // `icon` shows instead while it does not load (or loads empty)
    property string image
    readonly property bool imageOk: image !== "" && picture.status === Image.Ready && picture.implicitWidth > 0
    property bool dot: false
    property color dotColor: Theme.green
    property string text
    property color textColor: Theme.fg
    property string note
    property string detail
    property color detailColor: Theme.fg4
    property bool detailMono: false
    // > 0: the value gives way (from its start) past this width
    property real detailMax: 0
    // `trailing` takes the free space (a slider); the name then takes
    // textWidth
    property bool fillTrailing: false
    property real textWidth: 0
    property bool divider: false
    property bool clickable: false
    property bool action: false
    property bool danger: false
    property bool keyFocus: false
    readonly property bool hovered: hover.hovered
    default property alias trailing: trail.data
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Theme.listRowHeight

    // The pointer anywhere on the row, its buttons included
    HoverHandler {
        id: hover
    }
    // The thin line between the rows of a block
    Rectangle {
        visible: root.divider
        width: parent.width
        height: 1
        color: Theme.bg1
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radius
        color: root.danger ? Theme.danger : root.clickable && hover.hovered ? Theme.veil : Theme.clear
        Behavior on color {
            ColorAnimation { duration: Theme.dur(Theme.animFast) }
        }
        border.width: root.keyFocus ? Theme.focusWidth : 0
        border.color: Theme.focusRing
    }
    // Declared before the row, so buttons in `trailing` get their own clicks
    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 8

        Rectangle {
            visible: root.dot
            implicitWidth: 7
            implicitHeight: 7
            radius: 3.5
            color: root.dotColor
        }
        Image {
            id: picture
            visible: !root.dot && root.imageOk
            source: root.image
            sourceSize.width: 16
            sourceSize.height: 16
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        }
        Text {
            visible: !root.dot && !root.imageOk && root.icon !== ""
            Layout.minimumWidth: 16
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            textFormat: Text.PlainText
            color: root.danger ? Theme.red : root.action ? Theme.fg4 : root.iconColor
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        // The name: as wide as it needs, giving way first
        Text {
            Layout.fillWidth: !root.fillTrailing
            Layout.preferredWidth: root.fillTrailing ? root.textWidth : implicitWidth
            Layout.maximumWidth: root.fillTrailing ? root.textWidth : implicitWidth
            visible: root.text !== ""
            text: root.text
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: Text.ElideRight
            color: root.danger ? Theme.red : root.action ? Theme.fg4 : root.textColor
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            visible: root.note !== ""
            text: root.note
            textFormat: Text.PlainText
            maximumLineCount: 1
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSizeSmall
        }
        Item {
            visible: !root.fillTrailing
            Layout.fillWidth: true
        }
        Text {
            visible: root.detail !== ""
            Layout.maximumWidth: root.detailMax > 0 ? root.detailMax : Number.POSITIVE_INFINITY
            text: root.detail
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: root.detailMax > 0 ? Text.ElideLeft : Text.ElideNone
            color: root.danger ? Theme.red : root.detailColor
            font.family: root.detailMono ? Theme.monoFont : Theme.font
            font.pointSize: Theme.fontSizeSmall
        }
        RowLayout {
            id: trail
            Layout.fillWidth: root.fillTrailing
            spacing: 4
        }
    }
}
