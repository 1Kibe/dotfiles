import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.state

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

    implicitHeight: Theme.barHeight
    // Padding on both sides only as an island; the plain clock needs none.
    // Animated so the island grows out of the clock.
    implicitWidth: row.implicitWidth + (active ? 2 * Theme.spacing : 0)
    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
    }

    // Island background, only with music: the blurred cover (or the plain
    // island color without one), fading in and out
    CoverBackdrop {
        anchors.fill: parent
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
        spacing: root.active ? 6 : 0

        // Cover
        // Like the equalizer, it shrinks to width 0 and fades out without
        // music, so the clock alone stays centered.
        ClippingRectangle {
            Layout.preferredWidth: root.active ? 20 : 0
            implicitHeight: 20
            radius: 5
            color: Theme.bg1
            opacity: root.active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            // A note while the cover loads, or when the player sends none
            Text {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: "󰝚"
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 2
            }
            Image {
                id: cover
                anchors.fill: parent
                source: MediaState.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Decoded at twice the 20 px box: sharp on scaled screens
                // without keeping a full-size cover in memory
                sourceSize.width: 40
                sourceSize.height: 40
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
            Layout.preferredWidth: root.active ? 13 : 0
            implicitHeight: 12
            clip: true
            opacity: root.active ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: 3

                Rectangle {
                    required property int index
                    property real level: 4

                    // Grows up from the bottom of the 12 px box; 4 px when
                    // paused, a random 4-12 px while playing
                    x: index * 5
                    y: 12 - height
                    width: 3
                    height: root.playing ? level : 4
                    radius: 1.5
                    color: MediaState.tint   // a color from the cover
                    Behavior on color {
                        ColorAnimation { duration: Theme.animNormal }
                    }
                    // 150 ms: shorter than the fastest timer (170 ms), so each
                    // step ends before the next level arrives
                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.InOutSine }
                    }

                    Timer {
                        interval: 170 + index * 45   // a different pace per bar
                        repeat: true
                        running: root.playing
                        onTriggered: parent.level = 4 + Math.random() * 8
                    }
                }
            }
        }
    }

    // Hangs centered under the island, which grows and shrinks with the music
    MediaPanel {
        button: root
        centered: true
        open: root.open
        player: MediaState.player
        players: MediaState.players
    }
}
