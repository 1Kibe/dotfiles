import QtQuick
import QtQuick.Shapes
import qs.theme
import "../theme/corners.js" as Corners

// The minimized strip's outline on the right edge: a body bodyWidth wide
// from bodyTop to bodyTop + bodyHeight, its outer (left) corners round, and
// two concave corners flaring out along the screen's edge above and below
// it, with the same continuous corners as the bar's attached panels
// (theme/corners.js, Theme.cornerSmoothing). While it grows out of the edge
// (the drawer) the flares grow as the panels' do: radius × min(1,
// progress / 0.3), the progress being the width over the wire's.
Shape {
    id: root

    property real bodyWidth: 0
    property real bodyTop: 0
    property real bodyHeight: 0
    property color fillColor: Theme.stripFill
    readonly property real s: Theme.cornerSmoothing
    readonly property real edge: width
    readonly property real progress: Math.min(1, bodyWidth / Theme.wireWidth)
    readonly property real rf: Math.max(0, Math.min(Theme.minimizeRadius * Math.min(1, progress / 0.3),
                                                     bodyHeight / (2 * (1 + s))))
    // The outer corners never reach past half the body's width or height
    readonly property real ro: Math.max(0, Math.min(Theme.minimizeRadius, bodyWidth / (2 * (1 + s)),
                                                     bodyHeight / (2 * (1 + s))))

    visible: bodyWidth > 0 && bodyHeight > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.fillColor
        PathSvg {
            path: {
                const E = root.edge, t = root.bodyTop, b = root.bodyTop + root.bodyHeight
                const x = E - root.bodyWidth, s = root.s, rf = root.rf, ro = root.ro
                return `M ${E} ${t - Corners.reach(rf, s)} `
                     + Corners.corner(E, t, 0, 1, -1, 0, rf, s)
                     + Corners.corner(x, t, -1, 0, 0, 1, ro, s)
                     + Corners.corner(x, b, 0, 1, 1, 0, ro, s)
                     + Corners.corner(E, b, 1, 0, 0, 1, rf, s)
                     + "Z"
            }
        }
    }
}
