pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.theme

// The music the shell shows: the player picked in the music panel (or the
// one playing, or the first one), its track and cover, and a bright color
// taken from the cover. Shared by the center island and the music panel,
// so the cover colors are computed once.
Singleton {
    id: root

    // Read by bar/CenterIsland and bar/MediaPanel (player, track, artUrl, tint)
    readonly property var players: Mpris.players.values
    // The pick from the music panel while that player still exists, else
    // the one playing, else the first
    readonly property var player: players.find(p => p.dbusName === ShellState.mediaPlayer)
                                  ?? players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property string track: {
        if (!player || !player.trackTitle)
            return ""
        return player.trackArtist ? `${player.trackArtist} – ${player.trackTitle}` : player.trackTitle
    }
    readonly property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

    // A vivid color from the cover, bright enough for dark backgrounds;
    // accentLight without a cover or when the cover is too grey
    readonly property color tint: {
        let best = null
        let score = -1
        // quantizer.item is null while there is no cover file (LazyLoader below)
        const colors = quantizer.item ? quantizer.item.colors : []
        for (const c of colors) {
            // Most vivid = saturation x brightness; dark colors are skipped
            // since the tint is drawn on dark backgrounds
            const s = c.hsvSaturation * c.hsvValue
            if (c.hsvValue > 0.35 && s > score) {
                score = s
                best = c
            }
        }
        if (artUrl === "" || best === null || best.hsvSaturation < 0.25)
            return Theme.accentLight
        // A bit more saturation and at least 0.8 brightness, so text and
        // rings in this color stay readable
        return Qt.hsva(best.hsvHue, Math.min(1, best.hsvSaturation * 1.1), Math.max(0.8, best.hsvValue), 1)
    }

    // ColorQuantizer only reads local files, and covers (Spotify) come by
    // https: keep a local copy in the cache, alternating two names so the
    // quantizer sees a new source every time
    property string coverFile: ""
    property int coverSlot: 0

    // The URL comes from any MPRIS player: only http(s) is downloaded, with a
    // size and time limit, no redirect to another scheme, into a fixed name in
    // Quickshell's cache. Anything else, or a failure: no cover color.
    onArtUrlChanged: {
        if (artUrl === "")
            return
        // Local covers go to the quantizer as they are, no copy needed
        if (artUrl.startsWith("file://")) {
            coverFile = artUrl
            return
        }
        const scheme = artUrl.startsWith("https://") ? "https" : artUrl.startsWith("http://") ? "http" : ""
        if (scheme === "") {
            coverFile = ""
            return
        }
        // Into the other slot, after stopping any download still running for
        // the previous track
        coverSlot = 1 - coverSlot
        fetch.running = false
        fetch.target = Quickshell.cachePath(`cover-${coverSlot}`)
        fetch.command = ["curl", "-fsSL", "--max-time", "10", "--max-filesize", "5M",
                         "--proto", `=${scheme}`, "--proto-redir", "=https",
                         "--create-dirs", "-o", fetch.target, "--", artUrl]
        fetch.running = true
    }

    Process {
        id: fetch
        // Kept on the Process so the exit handler knows which file finished
        property string target
        onExited: code => root.coverFile = code === 0 ? `file://${target}` : ""
    }

    // The quantizer only exists while there is a cover; without one, tint
    // falls back to accentLight
    LazyLoader {
        id: quantizer
        active: root.coverFile !== ""

        ColorQuantizer {
            source: root.coverFile
            depth: 3            // up to 8 colors
            // Shrunk first: a few colors do not need the full image
            rescaleSize: 64
        }
    }
}
