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
    readonly property bool active: track !== ""
    readonly property bool playing: active && player !== null && player.isPlaying

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
                sourceSize.width: 40
                sourceSize.height: 40
            }
        }

        Clock {
            clickable: root.active
            tooltip: root.active && root.player ? `${root.track}\n${root.player.identity}` : fullDate
            onClicked: button => root.act(button)
        }

        // Equalizer: three bars that move while playing, still when paused
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

                    x: index * 5
                    y: 12 - height
                    width: 3
                    height: root.playing ? level : 4
                    radius: 1.5
                    color: MediaState.tint   // a color from the cover
                    Behavior on color {
                        ColorAnimation { duration: Theme.animNormal }
                    }
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

    MediaPanel {
        button: root
        centered: true
        open: root.open
        player: MediaState.player
        players: MediaState.players
    }
}
