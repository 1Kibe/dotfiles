import QtQuick
import QtQuick.Layouts
import qs.theme

// A card of a settings page: a title and its rows. `flash()` lights it up
// for a moment (a search result); `motion` plays its part of the page's
// cascade.
Rectangle {
    id: root

    property string title
    default property alias rows: column.data

    implicitHeight: column.implicitHeight + 24
    radius: Theme.radius
    color: Theme.veil
    border.width: 1
    border.color: Theme.alpha(Theme.accentLight, glow)

    // Its place in the page's cascade (CascadeMotion)
    transform: Translate { id: shift }
    readonly property alias motion: motionItem
    CascadeMotion {
        id: motionItem
        target: root
        translate: shift
    }

    property real glow: 0
    function flash() {
        glowAnim.restart()
    }
    SequentialAnimation {
        id: glowAnim
        NumberAnimation { target: root; property: "glow"; to: 0.9; duration: Theme.dur(Theme.searchFlash / 4) }
        NumberAnimation { target: root; property: "glow"; to: 0; duration: Theme.dur(Theme.searchFlash * 3 / 4); easing.type: Easing.InOutSine }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        Text {
            text: root.title
            color: Theme.fg4
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
            font.bold: true
        }
    }
}
