import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.state
import "mediaflight.js" as Flight

// Center of the bar: the clock, which becomes an island when music plays:
// a lighter background, a small cover on the left and an equalizer on the
// right (moving while playing). Hover: the track; click: the music panel;
// middle click: play/pause. Without music it is just the clock.
Item {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    readonly property string monitorName: monitor ? monitor.name : ""
    readonly property bool open: ShellState.isOpen("media", monitorName)

    readonly property var player: MediaState.player
    readonly property string track: MediaState.track
    // From MediaState. A player with no track title (idle, between tracks)
    // does not count: the bar shows the plain clock.
    readonly property bool active: track !== ""
    readonly property bool playing: active && player !== null && player.isPlaying

    // Shared by the island's MouseArea and the clock's own clicks
    function act(button) {
        if (!active)
            return
        if (button === Qt.MiddleButton) {
            if (player.canTogglePlaying)
                player.togglePlaying()
        } else {
            ShellState.toggle("media", monitorName)
        }
    }

    // While the music panel shows, the island is part of its shape (T1b):
    // its own background, cover and equalizer give way to the panel's (the
    // cover and the equalizer fly into the panel), and it narrows to the
    // clock during the second phase of the opening, following the panel
    readonly property bool joined: panel.visible
    readonly property real shrink: Flight.islandShrink(panel.progress)

    implicitHeight: Theme.barHeight
    // Padding on both sides only as an island; the plain clock needs none.
    // Animated so the island grows out of the clock (not while joined: the
    // panel's progress drives it then).
    implicitWidth: row.implicitWidth + (active ? 2 * Theme.spacing : 0)
    Behavior on implicitWidth {
        enabled: !root.joined
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // Island background, only with music: the blurred cover (or the plain
    // island color without one), fading in and out
    CoverBackdrop {
        anchors.fill: parent
        visible: !root.joined
        shown: root.active
        source: MediaState.artUrl
    }

    // Clicks on the cover and the equalizer (the clock handles its own)
    MouseArea {
        anchors.fill: parent
        enabled: root.active
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => root.act(event.button)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.active ? 6 * (1 - root.shrink) : 0

        // Cover
        // Like the equalizer, it shrinks to width 0 and fades out without
        // music, so the clock alone stays centered.
        ClippingRectangle {
            id: coverBox
            Layout.preferredWidth: root.active ? 20 * (1 - root.shrink) : 0
            implicitHeight: 20
            radius: 5
            // Joined: the cover is the panel's (it flies in), but its box keeps
            // its room, so the island narrows with the panel's progress
            color: root.joined ? Theme.clear : Theme.bg1
            opacity: root.active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }
            Behavior on Layout.preferredWidth {
                enabled: !root.joined
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            // A note while the cover loads, or when the player sends none
            Text {
                anchors.centerIn: parent
                visible: !root.joined && !cover.ready
                text: "󰝚"
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 2
            }
            // A new track's cover crossfades in once loaded
            CrossfadeImage {
                id: cover
                anchors.fill: parent
                visible: !root.joined
                source: MediaState.artUrl
                // Twice the 20 px box: sharp on scaled screens without keeping
                // a full-size cover in memory
                sourceSize: 40
            }
        }

        // Clickable only as an island; the tooltip shows the track and the
        // player's name, or the full date without music
        Clock {
            clickable: root.active
            tooltip: root.active && root.player ? `${root.track}\n${root.player.identity}` : fullDate
            onClicked: button => root.act(button)
        }

        // Equalizer: three bars that move while playing, still when paused
        // 13 px: three 3 px bars with a 2 px gap (x = index * 5)
        Item {
            id: eqBox
            Layout.preferredWidth: root.active ? 13 * (1 - root.shrink) : 0
            implicitHeight: 12
            clip: true
            opacity: root.active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }
            Behavior on Layout.preferredWidth {
                enabled: !root.joined
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            // Joined: the panel's equalizer (it flies in); the box keeps its room
            Equalizer {
                anchors.fill: parent
                visible: !root.joined
                playing: root.playing
                tint: MediaState.tint
            }
        }
    }

    // Hangs centered under the island, which grows and shrinks with the music
    MediaPanel {
        id: panel
        button: root
        islandCover: coverBox
        islandEq: eqBox
        centered: true
        open: root.open
        player: MediaState.player
        players: MediaState.players
    }
}
