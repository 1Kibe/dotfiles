import QtQuick
import QtQuick.Effects
import qs.theme

// A frozen picture leaving (wallpaper/SwapFrames), drawn from `source` (an
// item, hidden itself) as `progress` goes from 0 to 1: fade (it fades out),
// slide (it goes out to the left), curtain (its two halves run to the edges)
// or circle (a growing circle shows what is under it, from (ox, oy), or from
// the middle when they are negative, to the farthest corner).
Item {
    id: root

    property Item source: null
    property string kind: "fade"
    property real progress: 0
    property real ox: -1
    property real oy: -1

    // Fade and slide: the whole picture
    ShaderEffectSource {
        visible: root.kind === "fade" || root.kind === "slide"
        width: parent.width
        height: parent.height
        sourceItem: root.source
        hideSource: true
        x: root.kind === "slide" ? -root.progress * parent.width : 0
        opacity: root.kind === "fade" ? 1 - root.progress : 1
    }
    // Curtain: the two halves to the edges
    ShaderEffectSource {
        id: left
        visible: root.kind === "curtain"
        width: Math.ceil(parent.width / 2)
        height: parent.height
        sourceItem: root.source
        hideSource: true
        sourceRect: Qt.rect(0, 0, width, height)
        x: -root.progress * width
    }
    ShaderEffectSource {
        visible: root.kind === "curtain"
        width: parent.width - left.width
        height: parent.height
        sourceItem: root.source
        hideSource: true
        sourceRect: Qt.rect(left.width, 0, width, height)
        x: left.width + root.progress * width
    }
    // Circle: the picture outside a growing circle (a mask, no shader of
    // our own)
    ShaderEffectSource {
        id: whole
        anchors.fill: parent
        sourceItem: root.kind === "circle" ? root.source : null
        hideSource: true
        visible: false
    }
    Item {
        id: hole
        anchors.fill: parent
        visible: false
        layer.enabled: root.kind === "circle"
        readonly property real cx: root.ox >= 0 ? root.ox : width / 2
        readonly property real cy: root.oy >= 0 ? root.oy : height / 2
        readonly property real far: Math.sqrt(Math.pow(Math.max(cx, width - cx), 2) + Math.pow(Math.max(cy, height - cy), 2))
        readonly property real r: root.progress * far
        Rectangle {
            x: hole.cx - hole.r
            y: hole.cy - hole.r
            width: hole.r * 2
            height: hole.r * 2
            radius: hole.r
            color: Theme.text
        }
    }
    // (the tests read where the circle is)
    readonly property real circleX: hole.cx
    readonly property real circleY: hole.cy
    readonly property real circleRadius: hole.r
    readonly property real circleFar: hole.far
    MultiEffect {
        visible: root.kind === "circle"
        anchors.fill: parent
        source: whole
        maskEnabled: true
        maskInverted: true
        maskSource: hole
    }
}
