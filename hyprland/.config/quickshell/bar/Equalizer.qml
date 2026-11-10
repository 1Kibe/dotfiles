import QtQuick
import qs.theme

// Three bars that jump to new heights about 8 times a second while playing:
// no in-between frames, so the bar's window repaints only on each jump (a
// smooth animation would repaint it 60 times a second). Paused, the bars
// settle to the rest height in one short move and nothing keeps running.
// Sizes scale with the width (13 px = the island's: three 3 px bars, 2 px
// apart, up to 12 px tall).
Item {
    id: root

    property bool playing: false
    property color tint: Theme.accentLight
    readonly property real k: width / 13
    property var levels: [4, 4, 4]

    implicitWidth: 13
    implicitHeight: 12

    // One timer for the three bars: one repaint per step
    Timer {
        interval: 125
        repeat: true
        running: root.playing && root.visible
        onTriggered: root.levels = [4 + Math.random() * 8, 4 + Math.random() * 8, 4 + Math.random() * 8]
    }

    Repeater {
        model: 3

        Rectangle {
            required property int index
            x: index * 5 * root.k
            y: root.height - height
            width: 3 * root.k
            height: (root.playing ? root.levels[index] : 4) * root.k
            radius: 1.5 * root.k
            color: root.tint
            Behavior on color {
                ColorAnimation { duration: Theme.coverFade }
            }
            // Only the move to rest is animated (pausing)
            Behavior on height {
                enabled: !root.playing
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }
}
