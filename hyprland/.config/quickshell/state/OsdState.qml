pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.theme
import "../osd/osd.js" as Osd

// The notice in the middle of the screen (osd/Osd.qml draws it): what it
// shows and for how long. It follows the real state, not the keys: the
// default output's volume and mute (whoever changes them: the keys, an
// app, another client), and the default input's mute. The first reading
// and a change of the default device only set the base (they show
// nothing); a change after that shows. Never with the screen locked or
// asked to lock, nor while the volume panel or the control center is open
// (they show the slider themselves), nor without a focused monitor. Every
// value is a number kept in 0..1; nothing from outside is shown. The time
// runs only while it shows.
Singleton {
    id: root

    // What shows now
    property bool shown: false
    property string kind: ""            // "volume" | "mic" | "brightness"
    property real level: 0
    property bool muted: false
    property string monitor: ""
    // How many times it came in (a change while it shows only updates it)
    property int entries: 0
    // Hidden by a lock: gone at once, with no fade (set before shown goes)
    property bool cut: false
    // The time runs only while it shows (for the tests: nothing in repose)
    readonly property bool holding: hold.running
    signal appeared(string kind)

    readonly property bool locked: LockState.locked || LockState.wanted
    // (a capture: the shell's open, a recording or a quick print, never filmed)
    readonly property bool quiet: locked || ShellState.openPanel === "volume" || ShellState.openPanel === "control"
                                  || CaptureState.open || CaptureState.recording || CaptureState.printing
    onQuietChanged: {
        if (quiet)
            hide()
    }

    // ── Volume (the default output) and the microphone's mute ──
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sinkOk: sink !== null && sink.ready && sink.audio !== null
    readonly property bool sourceOk: source !== null && source.ready && source.audio !== null
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
    // One string per device and state: a change of it is a change to show,
    // unless the device itself changed (then only the base moves)
    readonly property string sinkState: sinkOk ? `${sink.id} ${sink.audio.volume} ${sink.audio.muted}` : ""
    readonly property string sourceState: sourceOk ? `${source.id} ${source.audio.muted}` : ""
    property string sinkBase: ""
    property string sourceBase: ""
    onSinkStateChanged: observe("sink", sinkState)
    onSourceStateChanged: observe("source", sourceState)
    Component.onCompleted: {
        sinkBase = sinkState
        sourceBase = sourceState
    }
    // A device's new state (osd/osd.js): shown only when it is a change of
    // the same device
    function observe(which, state) {
        const before = which === "sink" ? sinkBase : sourceBase
        if (which === "sink")
            sinkBase = state
        else
            sourceBase = state
        if (!Osd.isChange(before, state))
            return false
        const p = Osd.parse(state)
        return show(which === "sink" ? "volume" : "mic", p.volume, p.muted)
    }

    // Read again and show (the IPC target); false when there is nothing to
    // show or it may not show now
    function showVolume() {
        return sinkOk && show("volume", sink.audio.volume, sink.audio.muted)
    }

    // The focused monitor's name ("" for none)
    property string focusName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    // ── Brightness: read on request (the IPC target, the brightness keys),
    // through state/Brightness's reader; with no backlight, nothing shows ──
    function showBrightness() {
        Brightness.readOnce()
        return true
    }
    Connections {
        target: Brightness
        function onRead(available, percent) {
            if (available)
                root.show("brightness", percent / 100, false)
        }
    }

    function show(what, value, mute) {
        if (quiet || focusName === "")
            return false
        kind = what
        level = Osd.clamp(value)
        muted = mute === true
        monitor = focusName
        cut = false
        if (!shown) {
            shown = true
            entries++
            appeared(what)
        }
        hold.restart()
        return true
    }
    function hide() {
        hold.stop()
        cut = locked
        shown = false
    }
    // Reading time: never scaled by the animations' speed
    Timer {
        id: hold
        interval: Theme.osdHold
        onTriggered: root.shown = false
    }
}
