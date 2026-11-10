import QtQuick
import QtQuick.Shapes
import qs.theme
import "../theme/corners.js" as Corners

// The shape of a panel that hangs from the bar: the body, the concave corners
// where its sides meet the bar's edge and, optionally, a strip beside the bar
// up to the screen's top edge (the settings panel, which starts at x = 0
// while the bar keeps its side gap). One single path, so nothing inside it
// can show a seam; the only seam is the bar's edge, on a whole pixel.
//
// Corners: concave where a side meets the bar (flareLeft/flareRight), none on
// a side that continues the bar's end or touches the screen edge; the loose
// bottom corners rounded, or square on the screen's bottom edge. Every
// rounded corner is a continuous one (theme/corners.js): it reaches
// (1 + Theme.cornerSmoothing) × the radius along each side.
//
// The body unrolls from the bar as `progress` goes from 0 to 1: the visible
// height follows the progress and the concave corners grow during its first
// 30%, so a corner never shows without the panel under it.
//
// Island (islandWidth > 0, the music panel): the shape also takes the
// center island's box, from the screen's top edge down to the bar's edge,
// so island and panel are one piece. The island's own rounded bottom corners
// straighten during the first 15% of the progress, then inner corners grow
// where its sides meet the panel's top (15% to 30%): the panel's color runs
// into the bar there, like the concave corners.
//
// Coordinates are the bar-on-top ones; edge "bottom" mirrors the drawing
// (the panel opens upwards from the bar's top edge). bodyX, junctionY,
// visibleHeight, flareReach and bottomReach tell the window where the body
// and the corners are, for its content and mask.
Item {
    id: root

    property string edge: "top"           // the side of the screen the bar is on
    property bool flareLeft: true
    property bool flareRight: true
    property bool roundBottomLeft: true
    property bool roundBottomRight: true
    property real stripWidth: 0           // > 0: strip up to the screen's top on the left (no left flare then)
    property real stripHeight: 0          // its height: the bar's height
    property real islandX: 0              // the island's left edge, in this shape's coordinates
    property real islandWidth: 0          // > 0: island mode (the music panel)
    property real islandHeight: 0         // the bar's height: the island's box above the bar's edge
    property real islandRadius: 0         // the island's own bottom corners while closed
    property real bodyWidth: 0
    property real bodyHeight: 0
    property real progress: 0             // 0 = closed, 1 = open
    property real radius: Theme.radius
    property real smoothing: Theme.cornerSmoothing
    property color fill: Theme.barFill

    readonly property bool hasStrip: stripWidth > 0
    readonly property bool hasIsland: islandWidth > 0 && !hasStrip
    // Room for a concave corner at its full size, on each side that has one,
    // in whole pixels so the window's edges stay on the pixel grid
    readonly property real fullReach: Math.ceil(Corners.reach(radius, smoothing))
    readonly property real bodyX: (flareLeft && !hasStrip) ? fullReach : 0
    readonly property real junctionY: hasStrip ? stripHeight : hasIsland ? islandHeight : 0
    readonly property real visibleHeight: bodyHeight * Math.max(0, Math.min(1, progress))
    // The concave corners' radius now, and how far they reach
    readonly property real flare: radius * Math.max(0, Math.min(1, progress / 0.3))
    readonly property real flareReach: Corners.reach(flare, smoothing)
    // Bottom corners: never more than half the visible height
    readonly property real bottomRadius: Math.min(radius, visibleHeight / 2 / (1 + smoothing))
    readonly property real bottomReach: Corners.reach(bottomRadius, smoothing)
    // Island mode: its rounded bottom corners straighten (0–15%), then the
    // inner corners grow (15–30%)
    readonly property real islandCorner: islandRadius * Math.max(0, 1 - progress / 0.15)
    readonly property real innerRadius: radius * Math.max(0, Math.min(1, (progress - 0.15) / 0.15))

    implicitWidth: bodyX + bodyWidth + (flareRight ? fullReach : 0)
    implicitHeight: junctionY + bodyHeight

    // The outline as an SVG path, rebuilt when a size changes
    readonly property string outline: {
        const s = smoothing
        const j = junctionY
        const h = visibleHeight
        const xl = bodyX
        const xr = bodyX + bodyWidth
        const fl = (flareLeft && !hasStrip) ? flare : 0
        const fr = flareRight ? flare : 0
        const bl = roundBottomLeft ? bottomRadius : 0
        const br = roundBottomRight ? bottomRadius : 0
        const il = islandX
        const ir = islandX + islandWidth
        const ic = islandCorner
        const ii = innerRadius
        let d = hasStrip
            // along the screen's top, then down beside the bar's end
            ? `M 0 0 L ${stripWidth} 0 L ${stripWidth} ${j} `
            : hasIsland
            // along the screen's top over the island, down its right side to
            // the bar's edge: its own rounded corner, or an inner corner
            // running into the panel's top
            ? `M ${il} 0 L ${ir} 0 `
              + (ic > 0 ? Corners.corner(ir, j, 0, 1, -1, 0, ic, s)
                 : ii > 0 ? Corners.corner(ir, j, 0, 1, 1, 0, ii, s)
                 : `L ${ir} ${j} `)
            : `M ${xl - Corners.reach(fl, s)} ${j} `
        // along the bar's edge into the right side (concave), down, the
        // bottom-right corner, along the bottom, the bottom-left corner
        d += Corners.corner(xr, j, -1, 0, 0, 1, fr, s)
        d += Corners.corner(xr, j + h, 0, 1, -1, 0, br, s)
        d += Corners.corner(xl, j + h, -1, 0, 0, -1, bl, s)
        // up the left side: to the top (strip) or the left concave corner
        d += hasStrip ? "L 0 0 " : Corners.corner(xl, j, 0, -1, -1, 0, fl, s)
        // island: along the bar's edge to the island, then up its left side
        // (the mirror of the right one) back to the start
        if (hasIsland)
            d += ic > 0 ? Corners.corner(il, j, -1, 0, 0, -1, ic, s)
                 : ii > 0 ? Corners.corner(il, j, 1, 0, 0, -1, ii, s)
                 : `L ${il} ${j} `
        return d + "Z"
    }

    Shape {
        id: shape
        anchors.fill: parent
        visible: root.visibleHeight > 0
        // Smooth curves on the GPU; the software renderer (offscreen tests)
        // takes its own path
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.y: root.height / 2
            yScale: root.edge === "bottom" ? -1 : 1
        }

        ShapePath {
            fillColor: root.fill
            strokeWidth: -1
            PathSvg { path: root.outline }
        }
    }
}
