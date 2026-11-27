pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme

// The quick change of profile: a tap of Super+T goes to the next profile
// in the order and Super+Shift+T to the one before (round, with a notice,
// profiles/ProfileToast); Super+T held opens the carousel (profiles/
// ProfileOverlay, on the focused monitor; hypr/modules/profilekey.lua tells
// the tap from the hold). The carousel
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
        if (CaptureState.open)
            return "ocupada"
        // One thing open at a time
        ShellState.close()
        ClipboardStore.close()
        if (OverviewState.open)
            OverviewState.hide()
        index = Math.max(0, ProfileStore.profiles.findIndex(p => p.id === ProfileStore.active))
        openOn = monitor
        open = true
        return "ok"
    }
    // Super+T held: the carousel on `monitor`, left open when the key is let
    // go (already open: nothing)
    function show(monitor) {
        if (root.open)
            return "ok"
        return toggle(monitor)
    }
    // instant: no fade (before a change: the frozen frame must not hold it)
    property bool instant: false
    function close(instantly) {
        instant = instantly === true
        open = false
    }
    // The fan goes round; the grid stops at the ends
    function step(by) {
        if (count <= 0)
            return
        if (count <= Theme.profileFanMax)
            index = ((index + by) % count + count) % count
        else
            index = Math.max(0, Math.min(count - 1, index + by))
    }
    // The wheel and the touchpad (profiles/CarouselView): a step only once
    // the motion adds up to one notch of a wheel (120) or Theme.
    // profileSwipeStep pixels of a touchpad, at most one step each Theme.
    // animNormal (a fast flick never jumps several cards nor restarts the
    // fan's motion), the sum dropped at each step. A touchpad (pixel deltas)
    // moves only sideways, the way the fingers go; a plain wheel (notches
    // only) moves with its usual axis. Picking only: it never applies.
    property real wheelSum: 0
    property real wheelLast: -1e9
    function wheel(angleX, angleY, pixelX, pixelY, now) {
        const pad = pixelX !== 0 || pixelY !== 0
        const v = pad ? pixelX : (angleX !== 0 ? angleX : angleY)
        if (v === 0 || count <= 0)
            return false
        if (wheelSum !== 0 && Math.sign(v) !== Math.sign(wheelSum))
            wheelSum = 0
        const limit = pad ? Theme.profileSwipeStep : 120
        wheelSum += v
        if (Math.abs(wheelSum) < limit)
            return false
        if (now - wheelLast < Theme.animNormal) {
            // (too soon: held at the edge, no second step queued)
            wheelSum = Math.sign(wheelSum) * limit
            return false
        }
        const by = wheelSum > 0 ? -1 : 1
        wheelSum = 0
        wheelLast = now
        step(by)
        return true
    }
    // 5: the list changing while open
    onCountChanged: {
        if (count === 0)
            close(true)
        else
            index = Math.min(index, count - 1)
    }
    function pick(i) {
        if (i >= 0 && i < count)
            index = i
    }
    // Enter (from the middle) or a click (from the cursor): the picked one
    // applied, once the carousel is off the screen
    property string applying: ""
    property var applyingOpts: ({})
    function applyPicked(opts) {
        const p = picked
        if (!open || p === null)
            return
        close(true)
        if (p.id === ProfileStore.active && !ProfileStore.dirty)
            return
        applyAfterClose(p.id, opts)
    }
    // Any change asked while the carousel shows (IPC apply, Super+Shift+T):
    // it closes at once and the change waits for it to leave the screen
    function applyId(id, opts) {
        if (blocked() || ProfileStore.get(id) === null)
            return false
        if (open || afterClose.running) {
            close(true)
            applyAfterClose(id, opts)
            return true
        }
        return ProfileStore.apply(id, opts)
    }
    function applyAfterClose(id, opts) {
        applying = id
        applyingOpts = opts || {}
        afterClose.restart()
        leftScreen()
    }
    // The change starts once the closed carousel has left the screen (its
    // window gone: the frozen frame's capture comes after it; onShownChanged
    // below), 50 ms at most
    function leftScreen() {
        if (!shown && afterClose.running)
            Qt.callLater(() => {
                if (afterClose.running) {
                    afterClose.stop()
                    afterClose.triggered()
                }
            })
    }
    Timer {
        id: afterClose
        interval: 50
        onTriggered: {
            const id = root.applying
            root.applying = ""
            // (opened again meanwhile: not under it)
            if (!root.blocked() && !root.open && !ProfileStore.apply(id, root.applyingOpts))
                root.dropToast()
        }
    }

    // ── A tap of Super+T, Super+Shift+T (the selector closed) ──
    // The next one (or the one before) after the last asked (taps in a row go
    // round the order, never asking the same one twice), applied with the
    // transition; the notice shows once the change is over (never inside the
    // frame)
    property string lastNext: ""
    function next() {
        return go(1)
    }
    function prev() {
        return go(-1)
    }
    function go(by) {
        if (blocked())
            return "travada"
        if (!ProfileStore.ready)
            return "sem perfis"
        // With the selector open, the key only moves its pick (round, the
        // grid too); Enter or a click on the middle card applies
        if (open) {
            if (count > 0)
                index = ((index + by) % count + count) % count
            return "ok"
        }
        const list = ProfileStore.profiles
        if (list.length <= 1) {
            toast(null, "Só há um perfil")
            return "um perfil"
        }
        const from = (SwapState.busy || afterClose.running) && lastNext !== "" ? lastNext : ProfileStore.active
        const i = ((Math.max(0, list.findIndex(p => p.id === from)) + by) % list.length + list.length) % list.length
        const target = list[i]
        const waits = open || afterClose.running
        if (!applyId(target.id))
            return "recusado"
        lastNext = target.id
        toastFor = target.id
        if (!waits && !SwapState.busy)
            showToast()
        return "ok"
    }
    function dropToast() {
        toastFor = ""
        lastNext = ""
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
    // (only for the profile that really is the active one now)
    function showToast() {
        const list = ProfileStore.profiles
        const i = list.findIndex(p => p.id === toastFor)
        const ok = i >= 0 && ProfileStore.active === toastFor
        dropToast()
        if (ok)
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

    function onBlocked() {
        if (!blocked())
            return
        close(true)
        afterClose.stop()
        applying = ""
        dropToast()
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
            root.onBlocked()
        }
        function onWantedChanged() {
            root.onBlocked()
        }
        function onDimmedChanged() {
            root.onBlocked()
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
    // Registered while it shows, its fade out too (ProfileOverlay says when
    // its window is up): the minimize picture is never taken over it
    property bool shown: false
    onOpenChanged: ShellState.setOverlay("carousel", open || shown)
    onShownChanged: {
        ShellState.setOverlay("carousel", open || shown)
        leftScreen()
    }
}
