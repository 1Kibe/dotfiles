import QtQuick
import qs.theme
import qs.state
import "osd.js" as Osd

// The notice's square (osd/Osd.qml puts it in its window): the icon over a
// short bar, no number; mute shows an empty bar and its icon. Comes in with
// a fade and a short scale (reduce motion: only the fade), goes with a
// fade; a change while it shows only moves the bar. fading: the fade is
// still running (the window stays mapped for it).
Item {
    id: root

    property bool shown: false
    readonly property bool fading: fade.running

    implicitWidth: Theme.osdSize
    implicitHeight: Theme.osdSize

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Theme.osdSize
        height: Theme.osdSize
        radius: Theme.osdRadius
        color: Theme.stripFill
        opacity: root.shown ? 1 : 0
        scale: root.shown || Theme.reduceMotion ? 1 : 0.92
        // Locked: gone at once, so nothing is left fading to show on unlock
        Behavior on opacity {
            enabled: !OsdState.cut
            NumberAnimation {
                id: fade
                duration: Theme.dur(root.shown ? Theme.animNormal : Theme.animFast)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.shown ? Theme.curveDecel : Theme.curveAccel
            }
        }
        Behavior on scale {
            enabled: !Theme.reduceMotion
            NumberAnimation {
                duration: Theme.dur(Theme.animNormal)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveDecel
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Osd.icon(OsdState.kind, OsdState.level, OsdState.muted)
                textFormat: Text.PlainText
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.osdIconSize
            }
            // The bar: empty when muted
            Rectangle {
                width: Theme.osdBarWidth
                height: Theme.osdBarHeight
                radius: height / 2
                color: Theme.bg1
                clip: true

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accentLight
                    width: OsdState.muted ? 0 : parent.width * OsdState.level
                    Behavior on width {
                        enabled: !Theme.reduceMotion
                        NumberAnimation {
                            duration: Theme.dur(Theme.animFast)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveDecel
                        }
                    }
                }
            }
        }
    }
}
