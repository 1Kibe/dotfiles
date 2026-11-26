pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// The quick change of profile: Super+T (the carousel, profiles/
// ProfileOverlay, on the focused monitor) and Super+Shift+T (the next
// profile in the order, with a notice, profiles/ProfileToast). The carousel
// only picks and applies: moving through it applies nothing; Enter (or a
// click on the middle card) applies through the frozen frame's change, after
// the carousel is gone from the screen (the frame never holds it). One thing
// open at a time: it closes when the screen locks, when a bar panel, the
// overview, the capture or the clipboard opens, and when the focus goes to
// another monitor; opening it closes those. It never opens locked (nor while
// the monitors or the keyboard layout are applied).
Singleton {
    id: root

    property bool open: false
    property string openOn: ""
    // The profile picked in it (a place in ProfileStore.profiles)
    property int index: 0
    readonly property int count: ProfileStore.profiles.length
    readonly property var picked: index >= 0 && index < count ? ProfileStore.profiles[index] : null

    function blocked() {
        return LockState.locked || LockState.wanted || LockState.dimmed || MonitorsApply.pending
            || MonitorsApply.identifying || KeyboardLayout.pending
    }

    // Super+T on `monitor`; pressed again on the same one it closes
    function toggle(monitor) {
        if (open && openOn === monitor) {
            close()
            return "ok"
        }
        if (blocked())
            return "travada"
        if (!ProfileStore.ready || count === 0)
            return "sem perfis"
        // One thing open at a time
        ShellState.close()
        ClipboardStore.close()
        if (OverviewState.open)
            OverviewState.hide()
        if (CaptureState.open)
            return "ocupada"
        index = Math.max(0, ProfileStore.profiles.findIndex(p => p.id === ProfileStore.active))
        openOn = monitor
        open = true
        return "ok"
    }
    // instant: no fade (before a change: the frozen frame must not hold it)
    property bool instant: false
    function close(instantly) {
        instant = instantly === true
        open = false
    }
    function step(by) {
        if (count > 0)
            index = Math.max(0, Math.min(count - 1, index + by))
    }
    function pick(i) {
        if (i >= 0 && i < count)
            index = i
    }
    // Enter: the picked one applied, once the carousel is off the screen
    property string applying: ""
    function applyPicked() {
        const p = picked
        if (!open || p === null)
            return
        close(true)
        if (p.id === ProfileStore.active && !ProfileStore.dirty)
            return
        applying = p.id
        afterClose.restart()
    }
    Timer {
        id: afterClose
        // two frames for the closed carousel to leave the screen
        interval: 50
        onTriggered: {
            const id = root.applying
            root.applying = ""
            if (!root.blocked())
                ProfileStore.apply(id)
        }
    }

    // ── Super+Shift+T ──
    // The next one after the last asked (a held key goes round the order,
    // never asking the same one twice), applied with the transition; the
    // notice shows once the change is over (never inside the frame)
    property string lastNext: ""
    function next() {
        if (blocked())
            return "travada"
        if (!ProfileStore.ready)
            return "sem perfis"
        const list = ProfileStore.profiles
        if (list.length <= 1) {
            toast(null, "Só há um perfil")
            return "um perfil"
        }
        if (open)
            close(true)
        const from = SwapState.busy && lastNext !== "" ? lastNext : ProfileStore.active
        const i = (Math.max(0, list.findIndex(p => p.id === from)) + 1) % list.length
        const target = list[i]
        if (!ProfileStore.apply(target.id))
            return "recusado"
        lastNext = target.id
        toastFor = target.id
        if (!SwapState.busy)
            showToast()
        return "ok"
    }
    // The notice: the profile (its seal and name) and "N de M", or a text
    property var toastProfile: null
    property string toastText: ""
    property int toastSerial: 0
    property string toastFor: ""
    function toast(p, text) {
        toastProfile = p
        toastText = text
        toastSerial++
    }
    function showToast() {
        const list = ProfileStore.profiles
        const i = list.findIndex(p => p.id === toastFor)
        toastFor = ""
        lastNext = ""
        if (i >= 0)
            toast(list[i], `${i + 1} de ${list.length}`)
    }
    Connections {
        target: SwapState
        function onEnded() {
            if (root.toastFor !== "" && !SwapState.busy)
                root.showToast()
            else if (!SwapState.busy)
                root.lastNext = ""
        }
    }

    // ── One thing open at a time ──
    function closeIfOpen() {
        if (open)
            close()
    }
    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel !== "")
                root.closeIfOpen()
        }
    }
    Connections {
        target: ClipboardStore
        function onOpenChanged() {
            if (ClipboardStore.open)
                root.closeIfOpen()
        }
    }
    Connections {
        target: OverviewState
        function onOpenChanged() {
            if (OverviewState.open)
                root.closeIfOpen()
        }
    }
    Connections {
        target: CaptureState
        function onOpenChanged() {
            if (CaptureState.open)
                root.close(true)
        }
    }
    Connections {
        target: LockState
        function onLockedChanged() {
            if (root.blocked())
                root.close(true)
        }
        function onWantedChanged() {
            if (root.blocked())
                root.close(true)
        }
        function onDimmedChanged() {
            if (root.blocked())
                root.close(true)
        }
    }
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (root.open && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== root.openOn)
                root.closeIfOpen()
        }
    }
    // Its monitor gone
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.open && !Quickshell.screens.some(s => s.name === root.openOn))
                root.close(true)
        }
    }
    onOpenChanged: ShellState.setOverlay("carousel", open)
}
