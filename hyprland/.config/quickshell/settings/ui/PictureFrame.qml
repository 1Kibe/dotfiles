import QtQuick
import Quickshell.Widgets
import qs.theme

// A picture in a rounded frame (the wallpaper and photo galleries): the
// background, the picture cut to the inner curve (a Rectangle's clip is
// square, so a picture there would cover the rounded border), and the
// border drawn over it. Grows a little under the mouse.
Item {
    id: root

    property url source
    property size sourceSize
    property real radius: Theme.radius
    property color borderColor: Theme.clear
    property int colorDuration: Theme.dur(Theme.animFast)
    property bool hovered: false

    readonly property int borderWidth: 2

    scale: hovered && !Theme.reduceMotion ? 1.03 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.bg1
    }
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: root.borderWidth
        radius: Math.max(0, root.radius - root.borderWidth)
        color: Theme.clear

        Image {
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: root.sourceSize
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.clear
        border.width: root.borderWidth
        border.color: root.borderColor
        Behavior on border.color {
            ColorAnimation { duration: root.colorDuration }
        }
    }
}
