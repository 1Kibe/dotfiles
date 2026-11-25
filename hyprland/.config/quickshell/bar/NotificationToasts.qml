import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.theme
import qs.state
import qs.notifications

// The notifications on the screen: a drawer from the right edge, hung from
// the bar of the focused monitor like the settings' drawer on the left (the
// bar's end stretches to the edge first, then the drawer opens; the same
// timeline and tokens). Each new card comes in from the right, the room
// for it opening as it slides; one that goes slides back to the right and
// only then its room closes, the ones under it moving up. At most
// Theme.toastMax cards, then "e mais N" (they wait in the list). Never over
// the lock, the capture (Print) or the control center (it closes and the
// cards wait for it to close); no room reserved, no keyboard. What the
// cards say comes from NotificationState only.
AttachedPanel {
    id: root

    required property string monitorName
    readonly property bool focusedHere: Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === monitorName
    // Something else takes the right edge or the screen now: the drawer
    // closes, the cards keep their place for when it is gone
    readonly property bool held: ShellState.openPanel === "control" || CaptureState.open || NotificationState.locked

    edgeSide: "right"
    panelWidth: Theme.toastWidth + 12
    open: focusedHere && !held && cards.count > 0
    // One name per monitor: a focus change never lets one bar's "off" land
    // after another's "on"
    onVisibleChanged: ShellState.setOverlay("notificacoes:" + monitorName, visible)

    // The cards drawn, newest first: { cardId, count, leaving }. A card
    // that leaves NotificationState.screenList stays here while it slides
    // out; one of the same app that takes its place keeps its slot
    ListModel {
        id: cards
    }
    function indexOf(id) {
        for (let i = 0; i < cards.count; i++) {
            if (cards.get(i).cardId === id)
                return i
        }
        return -1
    }
    function appKeyOf(id) {
        const e = NotificationState.entries.find(x => x.id === id)
        return e ? e.appKey : ""
    }
    function sync() {
        const want = NotificationState.screenList
        const wanted = id => want.some(w => w.id === id)
        for (let k = want.length - 1; k >= 0; k--) {
            const w = want[k]
            let i = indexOf(w.id)
            if (i < 0) {
                // The same app's card on screen: this one takes its slot
                for (let j = 0; j < cards.count && i < 0; j++) {
                    const c = cards.get(j)
                    if (!wanted(c.cardId) && !w.urgent && appKeyOf(c.cardId) === w.appKey && w.appKey !== "")
                        i = j
                }
                if (i >= 0) {
                    cards.setProperty(i, "cardId", w.id)
                } else {
                    cards.insert(0, { cardId: w.id, count: w.count, leaving: false })
                    continue
                }
            }
            cards.setProperty(i, "count", w.count)
            cards.setProperty(i, "leaving", false)
        }
        for (let i = 0; i < cards.count; i++) {
            if (!wanted(cards.get(i).cardId))
                cards.setProperty(i, "leaving", true)
        }
    }
    function remove(id) {
        const i = indexOf(id)
        if (i >= 0 && cards.get(i).leaving)
            cards.remove(i)
    }
    Connections {
        target: NotificationState
        function onScreenListChanged() { root.sync() }
    }
    Component.onCompleted: sync()

    Column {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: cards

            Item {
                id: slot
                required property int cardId
                required property int count
                required property bool leaving
                // 0..1: its room in the pile; 1..0: off to the right
                property real room: 0
                property real out: 1
                width: Theme.toastWidth
                height: (toast.implicitHeight + Theme.toastGap) * room
                clip: true

                ToastCard {
                    id: toast
                    cardId: slot.cardId
                    count: slot.count
                    // Its time runs only while this pile shows it
                    active: root.open
                    x: Theme.reduceMotion ? 0 : slot.out * (Theme.toastWidth + 12)
                    opacity: Theme.reduceMotion ? 1 - slot.out : 1
                    onExpired: NotificationState.dismissToast(slot.cardId)
                }

                Component.onCompleted: {
                    if (!leaving)
                        comeIn.start()
                }
                onLeavingChanged: {
                    if (leaving) {
                        comeIn.stop()
                        goOut.start()
                    } else if (goOut.running) {
                        goOut.stop()
                        comeIn.start()
                    }
                }
                // In: the room opens as the card slides from the right
                ParallelAnimation {
                    id: comeIn
                    NumberAnimation {
                        target: slot; property: "room"; to: 1
                        duration: Theme.dur(Theme.animNormal)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                    }
                    NumberAnimation {
                        target: slot; property: "out"; to: 0
                        duration: Theme.dur(Theme.motionEdgeOpen)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                    }
                }
                // Out: to the right first, then its room closes
                SequentialAnimation {
                    id: goOut
                    NumberAnimation {
                        target: slot; property: "out"; to: 1
                        duration: Theme.dur(Theme.motionEdgeClose)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveAccel
                    }
                    NumberAnimation {
                        target: slot; property: "room"; to: 0
                        duration: Theme.dur(Theme.animNormal)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                    }
                    ScriptAction { script: root.remove(slot.cardId) }
                }
            }
        }
    }

    // The ones that did not fit wait in the list
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.bottomMargin: 4
        visible: NotificationState.moreCount > 0
        text: NotificationState.moreCount === 1 ? "e mais 1" : `e mais ${NotificationState.moreCount}`
        textFormat: Text.PlainText
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
