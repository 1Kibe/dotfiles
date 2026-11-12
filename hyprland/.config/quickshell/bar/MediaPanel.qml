import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.state
import "mediaflight.js" as Flight
import "../settings/hyprland.js" as Hypr

// Music panel: cover, title, artist, album and player; progress with time
// (click to seek); previous, play/pause, next. With more than one player,
// chips on top pick which one the bar and this panel control.
AttachedPanel {
    id: root

    // Both set by CenterIsland from MediaState, so the panel and the island
    // always show the same player
    required property var player
    required property var players
    readonly property bool hasPlayer: player !== null
    // The island's cover and equalizer (set by CenterIsland): they fly into
    // the panel while it opens (mediaflight.js) and back while it closes
    property Item islandCover: null
    property Item islandEq: null
    readonly property bool hasArt: MediaState.artUrl !== ""

    // The player's window in Hyprland, matched by app id / class against the
    // MPRIS desktop entry or name (Spotify: "spotify" ~ class "Spotify").
    // null for players without a window (mpv playing audio only).
    readonly property var playerWindow: {
        if (!hasPlayer)
            return null
        const keys = [player.desktopEntry, player.identity].filter(k => k).map(k => k.toLowerCase())
        for (const t of Hyprland.toplevels.values) {
            const ipc = t.lastIpcObject || {}
            const cls = ((t.wayland && t.wayland.appId) || ipc.class || "").toLowerCase()
            if (cls !== "" && keys.includes(cls))
                return t
        }
        return null
    }

    // m:ss for the progress labels (MPRIS position and length are seconds)
    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
    }

    panelWidth: 340
    // One piece with the center island (T1b): island, panel and corners
    // filled with the cover, blurred like the island's (AttachedPanel, from
    // CoverBackdrop), with a shade going from the island's to the panel's.
    // Without a cover: the island's color into the bar's. A new track's
    // cover crossfades in, together with its title.
    joinButton: true
    fillCover: hasArt ? MediaState.artUrl : ""
    fillColor: mix(Theme.islandFill, Theme.barFill, progress)
    fillShade: mix(Theme.coverShade, Theme.panelShade, progress)

    // Secondary text (album, player, times): on the cover the theme's grey
    // gets lost, so it is the main text color at 70%
    readonly property color softText: hasArt ? Theme.alpha(Theme.text, 0.7) : Theme.gray

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    // Where the cover and the equalizer start (in the island) and end (fixed
    // spots of the open panel). The start is read while the island has not
    // started narrowing (phase 1), then kept.
    property var coverFrom: ({ x: 0, y: 0, w: 20, h: 20, r: 5 })
    property var coverTo: ({ x: 0, y: 0, w: 72, h: 72, r: Theme.radius })
    property var eqFrom: ({ x: 0, y: 0, w: 13, h: 12, r: 1.5 })
    readonly property real eqScale: 1.6
    property var eqTo: ({ x: 0, y: 0, w: 13 * eqScale, h: 12 * eqScale, r: 1.5 * eqScale })
    function measure() {
        if (islandCover) {
            const p = islandCover.mapToItem(root, 0, 0)
            coverFrom = { x: p.x, y: p.y, w: 20, h: 20, r: 5 }
        }
        if (islandEq) {
            const q = islandEq.mapToItem(root, 0, 0)
            eqFrom = { x: q.x, y: q.y, w: 13, h: 12, r: 1.5 }
        }
        const c = openPos(coverSlot)
        coverTo = { x: c.x, y: c.y, w: 72, h: 72, r: Theme.radius }
        eqTo = { x: bodyLeft + bodyWidth - 14 - 13 * eqScale, y: bodyTop + 14,
                 w: 13 * eqScale, h: 12 * eqScale, r: 1.5 * eqScale }
    }
    onProgressChanged: {
        if (Flight.islandShrink(progress) === 0)
            measure()
    }
    // Also on showing: the island may have moved since the last opening,
    // and the first frame must start from where it is now
    onVisibleChanged: {
        if (visible)
            measure()
    }
    // The open body's top, and where a piece first stops, just past the
    // bar's edge (below it, or above it with the bar on the bottom edge)
    readonly property real bodyTop: mirrored ? junctionY - bodyHeight : junctionY
    function pastBar(h) {
        return mirrored ? junctionY - 6 - h : junctionY + 6
    }
    readonly property var coverNow: Flight.rectAt(progress, coverFrom, coverTo, pastBar(coverFrom.h))
    readonly property var eqNow: Flight.rectAt(progress, eqFrom, eqTo, pastBar(eqFrom.h))

    overlay: [
        // The one cover: from the island down into its place in the panel
        ClippingRectangle {
            visible: root.visible
            x: root.coverNow.x
            y: root.coverNow.y
            width: root.coverNow.w
            height: root.coverNow.h
            radius: root.coverNow.r
            color: Theme.bg1

            // A note while the cover loads, or when the player sends none
            Text {
                anchors.centerIn: parent
                visible: !cover.ready
                text: "󰝚"
                color: Theme.gray
                font.family: Theme.font
                font.pointSize: Math.max(1, (Theme.fontSize + 10) * parent.width / 72)
            }
            // A new track's cover crossfades in once loaded
            CrossfadeImage {
                id: cover
                anchors.fill: parent
                source: MediaState.artUrl
                // Twice the 72 px box, sharp on scaled screens
                sourceSize: 144
            }
        },
        // The equalizer: from the island's right to the panel's top-right
        // corner, growing; in steps while playing, still while paused
        Equalizer {
            visible: root.visible && root.hasPlayer
            x: root.eqNow.x
            y: root.eqNow.y
            width: root.eqNow.w
            height: root.eqNow.h
            playing: root.hasPlayer && root.player.isPlaying
            tint: MediaState.tint
        }
    ]

    // position is not reactive: read it once on opening (a paused player
    // would show 0:00 otherwise), then every second while playing
    onOpenChanged: {
        if (!open)
            return
        measure()
        if (hasPlayer)
            player.positionChanged()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.open && root.hasPlayer && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    // Player chips
    // A click stores the pick in ShellState.mediaPlayer, which MediaState
    // follows, so the center island switches too. Flow wraps the chips when
    // the names do not fit in one line.
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

        // The cover's place: the cover itself flies in from the island (see
        // the overlay above), so there is only ever one
        Item {
            id: coverSlot
            implicitWidth: 72
            implicitHeight: 72
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // A new track's title crossfades; it ends before the equalizer
            // in the corner
            CrossfadeText {
                Layout.fillWidth: true
                text: root.hasPlayer ? (root.player.trackTitle || "Sem título") : "Nada tocando"
                rightPadding: 13 * root.eqScale + 8
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize + 1
                font.bold: true
            }
            // Artist and album hide when the player sends none (videos,
            // streams), so the column does not keep empty lines
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
                color: root.softText
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            Text {
                Layout.fillWidth: true
                text: root.hasPlayer ? root.player.identity : ""
                elide: Text.ElideRight
                color: root.softText
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 2
            }
        }
    }

    // Progress: click to seek
    // Hidden for live streams and players that report no length.
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
                    color: MediaState.tint
                    Behavior on color {
                        ColorAnimation { duration: Theme.animNormal }
                    }
                    // No smoothing: one step a second, so the bar's window
                    // repaints once a second, not all the time (a smooth
                    // move would animate without end while playing)
                }
            }

            // Covers the full 12 px row, taller than the 4 px track, so the
            // bar is easy to hit. The click's x is the fraction of the track.
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
                color: root.softText
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            Text {
                text: root.hasPlayer ? root.time(root.player.length) : ""
                color: root.softText
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
        }
    }

    // Controls
    // Previous and next grey out when the player cannot do them; play/pause
    // is bigger and tinted with the cover color.
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
            textColor: MediaState.tint
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

    // Hyprland ignores a player's own raise() for a window on another
    // workspace, so focus the window here (this also switches workspace)
    PanelRow {
        visible: root.playerWindow !== null
        icon: "󰁔"
        text: `Ir para o ${root.hasPlayer ? root.player.identity : "player"}`
        onClicked: {
            // Checked first (settings/hyprland.js): it goes into Lua that
            // Hyprland runs; one that is not hex does nothing
            const hex = Hypr.windowAddress(root.playerWindow.address)
            ShellState.close()
            if (hex !== "")
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${hex}" })`)
        }
    }
}
