import QtQuick
import Quickshell.Services.Pipewire
import qs.theme

// Default output: icon by level and percent. Wheel ±5% (up to 100%,
// like the volume keys), click mutes.
BarItem {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ok: sink !== null && sink.ready && sink.audio !== null
    readonly property real volume: ok ? sink.audio.volume : 0
    readonly property bool muted: ok && sink.audio.muted
    readonly property int percent: Math.round(volume * 100)

    // Volume and mute are only live on tracked nodes
    PwObjectTracker {
        objects: [root.sink]
    }

    text: {
        if (!ok)
            return "󰝟"
        if (muted)
            return `󰝟 ${percent}%`
        const icon = volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾"
        return `${icon} ${percent}%`
    }
    textColor: !ok ? Theme.gray : muted ? Theme.red : Theme.text
    tooltip: ok ? (sink.description || sink.nickname || sink.name) : "Sem saída de áudio"

    onClicked: {
        if (ok)
            sink.audio.muted = !sink.audio.muted
    }
    onScrolled: steps => {
        if (!ok)
            return
        const v = sink.audio.volume
        if (steps > 0 && v >= 1)
            return   // above 100% (set by another app): don't push it further
        const next = Math.min(1, Math.max(0, v + 0.05 * steps))
        sink.audio.volume = Math.round(next * 100) / 100
    }
}
