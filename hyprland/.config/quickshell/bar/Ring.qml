import QtQuick
import QtQuick.Shapes
import qs.theme

// A ring that fills clockwise from the top with `value` (0 to 1), with an
// icon or a short text in the middle. Small in the bar, big in the system
// panel.
Item {
    id: root

    property real value: 0
    property color color: Theme.ringNormal
    property real thickness: 2.5
    property string text           // in the middle (icon or "12%")
    property int textSize: 11      // pixels
    property bool bold: false

    // Animated copy of value, so the ring moves smoothly between reads
    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    implicitWidth: Theme.ringSize
    implicitHeight: implicitWidth

    readonly property real radius: (width - thickness) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.ringTrack
            strokeWidth: root.thickness
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            // Nothing at 0: a round cap alone would draw a dot
            strokeColor: root.shown > 0.005 ? root.color : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360 * root.shown
            }
        }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.animNormal }
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: root.textSize
        font.bold: root.bold
    }
}
