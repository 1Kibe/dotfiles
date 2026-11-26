import QtQuick
import QtQuick.Shapes
import "../../theme/seal.js" as Seal

// The color seal of a profile's card: a square with its bottom right corner
// cut and four bands, drawn from theme/seal.js in 0-100 and scaled to the
// item. Its colors come from the profile it stands for (never the Theme of
// the moment): the outline and the gaps in the darkest tone, the thin band
// in a dark one, then the accent and two named colors.
Item {
    id: root

    property color outline
    property color thin
    property color accent
    property color colorA
    property color colorB

    implicitWidth: 48
    implicitHeight: 48

    Shape {
        width: 100
        height: 100
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: root.width / 100; yScale: root.height / 100 }
        ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.outline; PathSvg { path: Seal.POLYGONS.outline } }
        ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.thin; PathSvg { path: Seal.POLYGONS.band1 } }
        ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.accent; PathSvg { path: Seal.POLYGONS.band2 } }
        ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.colorA; PathSvg { path: Seal.POLYGONS.band3 } }
        ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.colorB; PathSvg { path: Seal.POLYGONS.band4 } }
    }
}
