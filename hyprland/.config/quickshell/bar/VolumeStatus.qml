import QtQuick
import Quickshell.Services.Pipewire
import qs.theme
import qs.state

// Default output: icon by level and percent. Wheel ±5% (up to 100%,
// like the volume keys); click opens the volume panel (mute is in there).
BarItem {
    id: root

    required property var monitor   // HyprlandMonitor of this bar
    readonly property string monitorName: monitor ? monitor.name : ""
    readonly property bool open: ShellState.isOpen("volume", monitorName)

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
    tooltip: open ? "" : ok ? (sink.description || sink.nickname || sink.name) : "Sem saída de áudio"

    onClicked: ShellState.toggle("volume", monitorName)
    onScrolled: steps => {
        if (!ok)
            return
        const v = sink.audio.volume
        if (steps > 0 && v >= 1)
            return   // above 100% (set by another app): don't push it further
        const next = Math.min(1, Math.max(0, v + 0.05 * steps))
        sink.audio.volume = Math.round(next * 100) / 100
    }

    VolumePanel {
        button: root
        open: root.open
    }
}
