import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.state
import qs.notifications
import "pileshape.js" as Pile

// The notifications on the screen: a pile on the screen's right edge, drawn
// in the bar's own window (the frame, Bar.qml) as one shape with the bar.
// The bar stretches its right end to the screen's edge first (the same
// share of the time as the settings' drawer: edgeBarShare), then each new
// card comes in from the right at the bottom of the pile (edgePanelFrom);
// one that goes slides back to the right and only then its room closes,
// the ones under it moving up; the last one going, the bar rounds its end
// again. The pile's outline follows every card as it slides
// (bar/pileshape.js): a step with its corners wherever two rows differ, a
// concave corner where the pile meets the bar. With the control center
// open, the pile hangs under it, 8 px apart, and goes back up when it
// closes. At most Theme.toastMax cards, then "e mais N" (they wait in the
// list). Gone at once over the lock or the capture (Print), and on any
// monitor but the focused one (the cards wait). No room reserved, no
// keyboard; it takes clicks only where it is drawn. What the cards say
// comes from NotificationState only.
Item {
    id: root

    required property var frame            // the bar's window (Bar.qml)
    required property string monitorName

    // (the tests set it: there is no Hyprland offscreen)
    property bool focusedHere: Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === monitorName
    // Hidden at once: another monitor in focus, the capture, the lock, or the
    // bar sliding away (a full screen): the cards wait
    readonly property bool hidden: !focusedHere || CaptureState.open || CaptureState.recording || NotificationState.locked
                                   || (frame !== null && frame.out > 0)
                                   || ShellState.openPanel === "notifications"
    readonly property bool mirrored: Theme.barAtBottom
    readonly property bool overCapture: false

    // What the frame reads: the right end of the bar stretched to the edge
    // (asked only while it stretches it: a hidden or settling pile never
    // takes the bar's right corner from a panel there)
    readonly property string edgeSide: edgeStep > 0 ? "right" : ""
    property real stretch: 0
    readonly property real edgeStep: hidden ? 0 : stretch

    // Sizes: a row is a card with a margin round it
    readonly property int pad: 6
    readonly property real rowWidth: Theme.toastWidth + 2 * pad
    readonly property real screenWidth: frame ? frame.width : 0
    readonly property real screenHeight: frame ? frame.height : 0
    readonly property real junction: Theme.barHeight

    // Where the pile begins: under the bar, or under the panels already on
    // the right edge of this monitor (the control center), Theme.toastGap
    // apart. Measured from the bar's edge side
    readonly property string edgeOwner: "notificacoes"
    readonly property real othersEdge: {
        if (cards.count === 0)
            return 0
        let y = 0
        const prefix = monitorName + "|"
        for (const key in ShellState.rightPanelEdges) {
            if (!key.startsWith(prefix) || key === prefix + edgeOwner)
                continue
            const v = ShellState.rightPanelEdges[key]
            const d = mirrored ? screenHeight - v : v
            y = Math.max(y, d)
        }
        return y
    }
    readonly property real wantTop: othersEdge > junction ? othersEdge + Theme.toastGap : junction
    property real pileTop: junction
    Binding on pileTop {
        value: root.wantTop
    }
    // Moving only while it already shows (a first card is born in its place)
    property bool settled: false
    Behavior on pileTop {
        enabled: root.settled && cards.count > 0 && !Theme.reduceMotion
        NumberAnimation {
            duration: Theme.dur(Theme.motionEdgeClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDecel
        }
    }

    parent: frame ? frame.panelLayer : null
    x: 0
    y: 0
    width: screenWidth
    height: screenHeight
    visible: cards.count > 0 || stretch > 0
    opacity: hidden ? 0 : 1
    onVisibleChanged: {
        if (!frame)
            return
        if (visible)
            frame.showPanel(root)
        else
            frame.hidePanel(root)
        syncOverlay()
    }
    onHiddenChanged: syncOverlay()
    onMonitorNameChanged: syncOverlay()
    // The overlay key in use: a monitor's name that comes late (or changes)
    // lets go of the old key, so no stale one keeps the screen "busy"
    property string overlayKey: ""
    function syncOverlay() {
        const key = monitorName !== "" ? "notificacoes:" + monitorName : ""
        if (overlayKey !== "" && overlayKey !== key)
            ShellState.setOverlay(overlayKey, false)
        overlayKey = key
        if (key !== "")
            ShellState.setOverlay(key, visible && !hidden)
    }

    // ── The bar's end: stretched before the first card, back after the last ──
    readonly property int stretchIn: Math.round(Theme.motionEdgeOpen * Theme.edgeBarShare)
    readonly property int stretchOut: Math.round(Theme.motionEdgeClose * Theme.edgeBarShare)
    NumberAnimation {
        id: stretchOpen
        target: root; property: "stretch"; to: 1
        duration: Theme.reduceMotion ? 0 : Theme.dur(root.stretchIn)
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
    }
    NumberAnimation {
        id: stretchClose
        target: root; property: "stretch"; to: 0
        duration: Theme.reduceMotion ? 0 : Theme.dur(root.stretchOut)
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveAccel
    }
    // A card about to come in: the bar first (how long the card waits)
    function openBar() {
        stretchClose.stop()
        if (stretch >= 0.99)
            return 0
        stretchOpen.restart()
        return Math.round(Theme.motionEdgeOpen * Theme.edgePanelFrom)
    }
    // The cards not leaving (kept up to date: a ListModel's roles are not
    // watched by bindings)
    property int liveN: 0
    function countLive() {
        let n = 0
        for (let i = 0; i < cards.count; i++) {
            if (!cards.get(i).leaving)
                n++
        }
        liveN = n
    }

    // (the tests read the rows)
    readonly property alias rowItems: rows
    readonly property alias moreItem: more

    // ── The cards drawn, oldest at the top: { cardId, count, leaving } ──
    // A card that leaves NotificationState.screenList stays here while it
    // slides out; one of the same app that takes its place keeps its slot
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
        settled = cards.count > 0
        const want = NotificationState.screenList
        const wanted = id => want.some(w => w.id === id)
        // Oldest first, so the newest goes to the bottom
        for (let k = want.length - 1; k >= 0; k--) {
            const w = want[k]
            let i = indexOf(w.id)
            if (i < 0) {
                for (let j = 0; j < cards.count && i < 0; j++) {
                    const c = cards.get(j)
                    if (!wanted(c.cardId) && !w.urgent && appKeyOf(c.cardId) === w.appKey && w.appKey !== "")
                        i = j
                }
                if (i >= 0) {
                    cards.setProperty(i, "cardId", w.id)
                } else {
                    cards.append({ cardId: w.id, count: w.count, leaving: false })
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
        countLive()
    }
    function remove(id) {
        const i = indexOf(id)
        if (i >= 0 && cards.get(i).leaving)
            cards.remove(i)
        countLive()
        if (cards.count === 0)
            stretchClose.restart()
    }
    // A card is out (its room still closing): with no other one left, the
    // bar's end goes back now
    function slidOut() {
        countLive()
        if (liveN === 0)
            stretchClose.restart()
    }
    Connections {
        target: NotificationState
        function onScreenListChanged() { root.sync() }
    }
    Component.onCompleted: sync()

    // ── The rows, from the pile's top; mirrored with the bar on the bottom ──
    Item {
        id: holder
        width: root.width
        height: root.height
        transform: Scale {
            origin.y: holder.height / 2
            yScale: root.mirrored ? -1 : 1
        }

        Column {
            id: column
            y: root.pileTop
            width: root.width

            Repeater {
                id: rows
                model: cards

                Item {
                    id: slot
                    required property int cardId
                    required property int count
                    required property bool leaving
                    // 0..1: its room in the pile; 1..0: off to the right
                    property real room: 1
                    property real out: 1
                    readonly property real rowHeight: toast.implicitHeight + 2 * root.pad
                    readonly property real leftX: root.screenWidth - root.rowWidth * (1 - out)
                    width: root.width
                    height: rowHeight * room

                    ToastCard {
                        id: toast
                        x: Theme.reduceMotion ? root.screenWidth - root.rowWidth + root.pad : slot.leftX + root.pad
                        y: root.pad
                        opacity: Theme.reduceMotion ? 1 - slot.out : 1
                        cardId: slot.cardId
                        count: slot.count
                        // Its time runs only while the pile shows it
                        active: root.visible && !root.hidden && !slot.leaving
                        onExpired: NotificationState.dismissToast(slot.cardId)
                        transform: Scale {
                            origin.y: toast.height / 2
                            yScale: root.mirrored ? -1 : 1
                        }
                    }

                    function enter() {
                        wait.duration = Theme.dur(root.openBar())
                        comeIn.restart()
                    }
                    Component.onCompleted: {
                        if (!leaving)
                            enter()
                    }
                    onLeavingChanged: {
                        if (leaving) {
                            comeIn.stop()
                            goOut.restart()
                            root.countLive()
                        } else if (goOut.running) {
                            goOut.stop()
                            enter()
                        }
                    }
                    // In: the bar's end first (if it is not there yet), then
                    // the card slides in from the right
                    SequentialAnimation {
                        id: comeIn
                        PauseAnimation { id: wait }
                        ParallelAnimation {
                            NumberAnimation {
                                target: slot; property: "out"; to: 0
                                duration: Theme.dur(Math.round(Theme.motionEdgeOpen * (1 - Theme.edgePanelFrom)))
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                            }
                            // (a slot taken back while its room was closing
                            // opens it again)
                            NumberAnimation {
                                target: slot; property: "room"; to: 1
                                duration: Theme.dur(Theme.motionEdgeClose)
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                            }
                        }
                    }
                    // Out: to the right first, then its room closes
                    SequentialAnimation {
                        id: goOut
                        NumberAnimation {
                            target: slot; property: "out"; to: 1
                            duration: Theme.dur(Math.round(Theme.motionEdgeClose * (1 - Theme.edgePanelFrom)))
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveAccel
                        }
                        // Out of the screen: the bar's end may go back now
                        ScriptAction { script: root.slidOut() }
                        NumberAnimation {
                            target: slot; property: "room"; to: 0
                            duration: Theme.dur(Theme.motionEdgeClose)
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
                        }
                        ScriptAction { script: root.remove(slot.cardId) }
                    }
                }
            }

            // The ones that did not fit wait in the list
            Item {
                id: more
                width: root.width
                height: NotificationState.moreCount > 0 && root.liveN > 0 ? 26 : 0
                visible: height > 0
                Text {
                    x: root.screenWidth - root.rowWidth + root.pad + 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotificationState.moreCount === 1 ? "e mais 1" : `e mais ${NotificationState.moreCount}`
                    textFormat: Text.PlainText
                    color: Theme.fg4
                    font.family: Theme.fontPanels
                    font.pointSize: Theme.fontSize - 1
                    transform: Scale {
                        origin.y: 13
                        yScale: root.mirrored ? -1 : 1
                    }
                }
            }
        }
    }

    // ── The shape: every row as it is now (bar/pileshape.js) ──
    readonly property var segments: {
        const out = []
        for (let i = 0; i < rows.count; i++) {
            const s = rows.itemAt(i)
            if (s)
                out.push({ x: Theme.reduceMotion ? screenWidth - rowWidth : s.leftX, y: pileTop + s.y, h: s.height })
        }
        if (more.height > 0) {
            const minX = out.length > 0 ? Math.min(...out.map(r => r.x)) : screenWidth
            out.push({ x: Math.max(minX, screenWidth - rowWidth), y: pileTop + more.y, h: more.height })
        }
        return out
    }
    // The top row on the screen (a row all off the screen is not drawn)
    readonly property var firstShown: {
        let f = null
        for (const r of segments) {
            if (r.x < screenWidth - 0.5 && r.h > 0.5 && (f === null || r.y < f.y))
                f = r
        }
        return f
    }
    // The concave corner on the bar: it grows while the pile meets the bar
    // (as the first card comes in, as the pile goes back up under it) and
    // goes as it leaves it
    readonly property bool meetsBar: firstShown !== null && Math.abs(firstShown.y - junction) < 0.5
    property real attachRadius: meetsBar ? Theme.radius : 0
    Behavior on attachRadius {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: Theme.dur(Theme.animFast); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
    }
    readonly property real topRadius: firstShown === null ? 0
        : Math.min(attachRadius, Theme.radius * Math.max(0, Math.min(1, (screenWidth - firstShown.x) / (rowWidth * 0.3))))
    readonly property var outline: Pile.outline(screenWidth, segments, junction, Theme.radius, topRadius, Theme.cornerSmoothing)

    Shape {
        parent: root.frame ? root.frame.shapeLayer : root
        width: root.screenWidth
        height: root.screenHeight
        visible: root.visible && !root.hidden && root.outline.path !== ""
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.y: root.screenHeight / 2
            yScale: root.mirrored ? -1 : 1
        }
        ShapePath {
            fillColor: Theme.barFill
            strokeWidth: -1
            PathSvg { path: root.outline.path }
        }
    }

    // ── Clicks only where the pile is (nothing while hidden) ──
    readonly property real leftmost: segments.length > 0 ? Math.min(...segments.map(r => r.x)) : screenWidth
    readonly property Region maskRegion: Region {
        item: maskArea
    }
    Item {
        id: maskArea
        x: root.leftmost
        // From the top row drawn (never the room of one sliding out above)
        readonly property real from: root.firstShown !== null ? root.firstShown.y : root.pileTop
        y: root.mirrored ? root.screenHeight - root.outline.lowest : from
        width: root.hidden ? 0 : root.screenWidth - root.leftmost
        height: root.hidden || root.outline.lowest <= from ? 0 : root.outline.lowest - from
    }

    // The minimized windows' strip slides out of the pile's way
    readonly property real stripEdge: visible && !hidden && outline.lowest > 0
                                      ? Math.round(mirrored ? screenHeight - outline.lowest : outline.lowest) : 0
    onStripEdgeChanged: ShellState.setRightPanelEdge(monitorName, stripEdge, edgeOwner)
    // A monitor gone with the pile showing: nothing of it stays
    Component.onDestruction: {
        ShellState.setRightPanelEdge(monitorName, 0, edgeOwner)
        if (overlayKey !== "")
            ShellState.setOverlay(overlayKey, false)
    }
}
