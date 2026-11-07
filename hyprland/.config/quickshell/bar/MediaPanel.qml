import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme
import qs.state

// Music panel: cover, title, artist, album and player; progress with time
// (click to seek); previous, play/pause, next. With more than one player,
// chips on top pick which one the bar and this panel control.
DropPanel {
    id: root

    required property var player
    required property var players
    readonly property bool hasPlayer: player !== null

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
    }

    panelWidth: 340

    // position is not reactive: refresh it while playing, only when visible
    Timer {
        interval: 1000
        repeat: true
        running: root.open && root.hasPlayer && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    // Player chips
    Flow {
        visible: root.players.length > 1
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        spacing: 4

        Repeater {
            model: root.players

            BarItem {
                required property var modelData
                text: modelData.identity
                textColor: modelData === root.player ? Theme.text : Theme.gray
                onClicked: ShellState.mediaPlayer = modelData.dbusName
            }
        }
    }

    // Cover and track
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 8
        spacing: 12

        ClippingRectangle {
            implicitWidth: 72
            implicitHeight: 72
            radius: Theme.radius
            color: Theme.bg1

            Text {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: "󰝚"
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize + 10
            }
            Image {
                id: cover
                anchors.fill: parent
                source: root.hasPlayer ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 144
                sourceSize.height: 144
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.hasPlayer ? (root.player.trackTitle || "Sem título") : "Nada tocando"
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize + 1
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.hasPlayer ? root.player.trackArtist : ""
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.hasPlayer ? root.player.trackAlbum : ""
                elide: Text.ElideRight
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            Text {
                Layout.fillWidth: true
                text: root.hasPlayer ? root.player.identity : ""
                elide: Text.ElideRight
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 2
            }
        }
    }

    // Progress: click to seek
    ColumnLayout {
        visible: root.hasPlayer && root.player.lengthSupported && root.player.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        spacing: 4

        Item {
            Layout.fillWidth: true
            implicitHeight: 12

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Theme.bg2

                Rectangle {
                    width: root.hasPlayer && root.player.length > 0
                           ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accentLight
                    Behavior on width {
                        NumberAnimation { duration: Theme.animNormal }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.hasPlayer && root.player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: event => root.player.position = root.player.length * (event.x / width)
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.hasPlayer ? root.time(root.player.position) : ""
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            Text {
                text: root.hasPlayer ? root.time(root.player.length) : ""
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
        }
    }

    // Controls
    RowLayout {
        visible: root.hasPlayer
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 4
        spacing: 16

        BarItem {
            text: "󰒮"
            fontSize: Theme.fontSize + 4
            clickable: root.hasPlayer && root.player.canGoPrevious
            textColor: clickable ? Theme.text : Theme.gray
            onClicked: root.player.previous()
        }
        BarItem {
            text: root.hasPlayer && root.player.isPlaying ? "󰏤" : "󰐊"
            fontSize: Theme.fontSize + 8
            onClicked: {
                if (root.player.canTogglePlaying)
                    root.player.togglePlaying()
            }
        }
        BarItem {
            text: "󰒭"
            fontSize: Theme.fontSize + 4
            clickable: root.hasPlayer && root.player.canGoNext
            textColor: clickable ? Theme.text : Theme.gray
            onClicked: root.player.next()
        }
    }

    PanelRow {
        visible: root.hasPlayer && root.player.canRaise
        icon: "󰏌"
        text: `Abrir o ${root.hasPlayer ? root.player.identity : "player"}`
        onClicked: {
            ShellState.close()
            root.player.raise()
        }
    }
}
