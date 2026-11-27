import QtQuick
import qs.theme

// A text button (with an optional Nerd Font icon); hover changes its color
// with a short fade (Theme.animFast)
Rectangle {
    id: root

    property string text
    property string icon
    // danger: armed, waiting for the second click; destructive: an action
    // that removes something (red text and icon even before)
    property bool danger: false
    property bool destructive: false
    // primary: the main action of a view, in the accent; outline: a second
    // action, an accent border; flat: a third one, text only
    property bool primary: false
    property bool outline: false
    property bool flat: false
    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 28
    radius: Theme.radius
    color: danger ? Theme.danger : primary ? (mouse.containsMouse ? Theme.accentLight : Theme.accent)
           : outline || flat ? (mouse.containsMouse ? Theme.alpha(Theme.accent, 0.12) : Theme.clear)
           : mouse.containsMouse ? Theme.bg2 : Theme.bg1
    border.width: outline ? 1 : 0
    border.color: Theme.accent
    Behavior on color {
        ColorAnimation { duration: Theme.dur(Theme.animFast) }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon !== "" ? `${root.icon}  ${root.text}` : root.text
        // (a profile's name may be in it)
        textFormat: Text.PlainText
        color: root.danger || root.destructive ? Theme.red : root.primary ? Theme.bgHard : root.outline ? Theme.accentLight : Theme.text
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
