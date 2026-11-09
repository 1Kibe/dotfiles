import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.state
import "text.js" as Clean

// Music card at the bottom of the lock screen: cover, title, artist and
// previous / play-pause / next. Only while a player exists. Nothing opens
// an app or a link from here, and the cover is shown only when the player
// gives a local file (never downloaded). Lock screen only: the login screen
// has no music, so this file is not copied with the other lock/ parts.
Rectangle {
    id: root

    readonly property var player: MediaState.player
    readonly property bool hasPlayer: player !== null
    // file:// only; Spotify and browsers send https covers, which stay out
    readonly property string cover: hasPlayer && player.trackArtUrl && player.trackArtUrl.startsWith("file://")
                                    ? player.trackArtUrl : ""

    visible: hasPlayer
    implicitWidth: Theme.lockMediaWidth
    implicitHeight: 72
    radius: Theme.pillRadius
    color: Theme.lockPillFill

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        ClippingRectangle {
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            radius: 8
            color: Theme.alpha(Theme.bg2, 0.8)

            Image {
                anchors.fill: parent
                visible: status === Image.Ready
                source: root.cover
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: 104
                sourceSize.height: 104
            }

            Text {
                anchors.centerIn: parent
                visible: root.cover === ""
                text: "󰝚"
                color: Theme.fg4
                font.family: Theme.font
                font.pixelSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Player texts: plain text, one line, no control or bidi
            // characters (text.js), cut to a sane length
            Text {
                Layout.fillWidth: true
                text: root.hasPlayer ? Clean.clean(root.player.trackTitle, 120) : ""
                textFormat: Text.PlainText
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                clip: true
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.hasPlayer ? Clean.clean(root.player.trackArtist, 120) : ""
                textFormat: Text.PlainText
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                clip: true
                elide: Text.ElideRight
                color: Theme.fg4
                font.family: Theme.font
                font.pixelSize: 13
            }
        }

        // Previous, play/pause, next: the only actions on the lock screen
        Repeater {
            model: [
                { icon: "󰒮", act: "prev" },
                { icon: root.hasPlayer && root.player.isPlaying ? "󰏤" : "󰐊", act: "play" },
                { icon: "󰒭", act: "next" }
            ]

            Rectangle {
                required property var modelData
                readonly property bool enabledHere: root.hasPlayer
                    && (modelData.act === "prev" ? root.player.canGoPrevious
                        : modelData.act === "next" ? root.player.canGoNext
                        : root.player.canTogglePlaying)
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: mouse.containsMouse && enabledHere ? Theme.veil : Theme.clear
                opacity: enabledHere ? 1 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 18
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.enabledHere
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.act === "prev")
                            root.player.previous()
                        else if (modelData.act === "next")
                            root.player.next()
                        else
                            root.player.togglePlaying()
                    }
                }
            }
        }
    }
}
