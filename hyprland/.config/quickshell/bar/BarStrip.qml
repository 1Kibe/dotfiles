import QtQuick
import QtQuick.Shapes
import qs.theme
import "../theme/corners.js" as Corners

// The bar's fill (Bar.qml): one translucent strip, square at the top, with
// continuous bottom corners (theme/corners.js, like the panels'). Placed on
// the bar; stretchLeft/Right take its ends that far past the bar, to the
// screen's edge (a panel touching that edge, bar/EdgeTimeline), without
// moving the bar's items.
Item {
    id: root

    property real cornerLeft: Theme.barRadius
    property real cornerRight: Theme.barRadius
    property real stretchLeft: 0
    property real stretchRight: 0
    property color fill: Theme.barFill

    Shape {
        id: strip
        x: -root.stretchLeft
        width: root.width + root.stretchLeft + root.stretchRight
        height: root.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fill
            strokeWidth: -1
            PathSvg {
                path: {
                    const w = strip.width, h = strip.height, s = Theme.cornerSmoothing
                    return `M 0 0 L ${w} 0 `
                        + Corners.corner(w, h, 0, 1, -1, 0, root.cornerRight, s)
                        + Corners.corner(0, h, -1, 0, 0, -1, root.cornerLeft, s)
                        + "Z"
                }
            }
        }
    }
}
