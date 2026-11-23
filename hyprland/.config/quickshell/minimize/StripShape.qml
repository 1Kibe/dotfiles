import QtQuick
import QtQuick.Shapes
import qs.theme
import "stripcurve.js" as Curve

// The minimized strip's outline on the right edge: a body bodyWidth wide
// from bodyTop to bodyTop + bodyHeight (minimize/stripcurve.js). On the
// wire, a long curve above and below, concave then convex, from the
// screen's edge across the whole width; open (icons, names), the bar's
// panels' corners (the concave one and the outer one with the Theme's
// radius); in between, the one going into the other with the width, with
// no jump. Coming out of the edge (the drawer) the curve grows with it.
Shape {
    id: root

    property real bodyWidth: 0
    property real bodyTop: 0
    property real bodyHeight: 0
    property color fillColor: Theme.stripFill
    readonly property real edge: width
    readonly property var m: ({
        wire: Theme.wireWidth, icons: Theme.minimizeIcons, reach: Theme.minimizeWireReach, depth: Theme.minimizeWireDepth,
        radius: Theme.minimizeRadius, s: Theme.cornerSmoothing
    })
    // From the wire (0) to open (1), and the open corners' radii (tests)
    readonly property real open: Curve.openShare(bodyWidth, m)
    readonly property var radii: Curve.radii(bodyWidth, bodyHeight, Theme.minimizeRadius, Theme.cornerSmoothing,
                                             Math.min(1, bodyWidth / Theme.wireWidth / 0.3))

    visible: bodyWidth > 0 && bodyHeight > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.fillColor
        PathSvg {
            path: Curve.path(root.edge, root.bodyTop, root.bodyHeight, root.bodyWidth, root.m)
        }
    }
}
