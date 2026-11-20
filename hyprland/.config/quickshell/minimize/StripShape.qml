import QtQuick
import QtQuick.Shapes
import qs.theme

// The minimized strip's outline on the right edge: a body bodyWidth wide
// from bodyTop to bodyTop + bodyHeight, its outer (left) corners round, and two concave
// corners flaring out along the screen's edge above and below it, as the
// bar's attached panels do. While it grows out of the edge (drawer) the
// corners grow with it: radius × min(1, bodyWidth / wire). Drawn in the parent's
// coordinates; the right edge is the parent's right side.
Shape {
    id: root

    property real bodyWidth: 0
    property real bodyTop: 0
    property real bodyHeight: 0
    property color fillColor: Theme.stripFill
    readonly property real edge: width
    readonly property real r: Math.max(0, Math.min(Theme.minimizeRadius * Math.min(1, bodyWidth / Theme.wireWidth), bodyHeight / 2))
    // The outer corners never round past half the body's width
    readonly property real ro: Math.min(r, bodyWidth / 2)

    visible: bodyWidth > 0 && bodyHeight > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.fillColor
        PathSvg {
            path: {
                const E = root.edge, t = root.bodyTop, b = root.bodyTop + root.bodyHeight, x = E - root.bodyWidth, r = root.r, ro = root.ro
                return `M ${E} ${t - r} Q ${E} ${t} ${E - r} ${t} L ${x + ro} ${t} Q ${x} ${t} ${x} ${t + ro} `
                     + `L ${x} ${b - ro} Q ${x} ${b} ${x + ro} ${b} L ${E - r} ${b} Q ${E} ${b} ${E} ${b + r} Z`
            }
        }
    }
}
