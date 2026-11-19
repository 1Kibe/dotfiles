import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.theme
import qs.state
import qs.bar
import "levels.js" as Levels

// The control center's volume: the default output's mute button, slider
// (0..100%, the wheel ±5%) and percent, and the arrow that folds out the
// mixer section. The output is tracked only while the control center is
// open (volume and mute need a tracked node); closed, nothing is tracked.
RowLayout {
    id: root

    // The control center open
    required property bool active
    // The part the keyboard is on: "slider", "mixer" or ""
    property string keyPart: ""

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ok: sink !== null && sink.ready && sink.audio !== null
    readonly property bool muted: ok && sink.audio.muted
    readonly property int trackedCount: tracker.objects.length

    PwObjectTracker {
        id: tracker
        objects: root.active && root.sink !== null ? [root.sink] : []
    }

    // ←/→ and the wheel: 5% per step, never past 100%
    function step(steps) {
        if (ok)
            sink.audio.volume = Levels.stepVolume(sink.audio.volume, steps)
    }
    function toggleMute() {
        if (ok)
            sink.audio.muted = !sink.audio.muted
    }

    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.rightMargin: 4
    spacing: 6

    BarItem {
        // nf-md-volume_off / nf-md-volume_high, as the bar's volume
        text: String.fromCodePoint(!root.ok || root.muted ? 0xF075F : 0xF057E)
        textColor: !root.ok ? Theme.gray : root.muted ? Theme.red : Theme.text
        tooltip: root.muted ? "Ativar o som" : "Silenciar"
        onClicked: root.toggleMute()
    }
    PanelSlider {
        Layout.fillWidth: true
        value: root.ok ? root.sink.audio.volume : 0
        muted: root.muted
        keyFocus: root.keyPart === "slider"
        onMoved: v => {
            if (root.ok)
                root.sink.audio.volume = v
        }
    }
    // Fixed width so the slider does not jump as the digits change
    Text {
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        textFormat: Text.PlainText
        text: root.ok ? `${Math.round(root.sink.audio.volume * 100)}%` : ""
        color: root.muted ? Theme.red : Theme.text
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }
    // nf-md-chevron_down: the mixer, half a turn while open
    BarItem {
        text: String.fromCodePoint(0xF0140)
        textColor: Theme.gray
        tooltip: ShellState.controlSection === "mixer" ? "" : "Mixer"
        keyFocus: root.keyPart === "mixer"
        rotation: ShellState.controlSection === "mixer" ? 180 : 0
        Behavior on rotation {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.dur(Theme.animNormal); easing.type: Easing.OutCubic }
        }
        onClicked: ShellState.setControlSection("mixer")
    }
}
