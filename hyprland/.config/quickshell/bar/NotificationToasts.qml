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
    readonly property bool hidden: !focusedHere || CaptureState.open || CaptureState.recording || CaptureState.printing
                                   || NotificationState.locked
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
    // The other panels on this edge, without the pile's own entry: a copy
    // that changes only when theirs do (the pile's own edge follows the
    // pile; reading it here would loop)
    property var others: []
    function readOthers() {
        const out = []
        const prefix = monitorName + "|"
        for (const key in ShellState.rightPanelEdges) {
            if (!key.startsWith(prefix) || key === prefix + edgeOwner)
                continue
            const sp = ShellState.rightPanelSpans[key] ?? null
            out.push({ edge: ShellState.rightPanelEdges[key], span: sp ? { left: sp.left, right: sp.right } : null })
        }
        if (JSON.stringify(out) !== JSON.stringify(others))
            others = out
    }
    Connections {
        target: ShellState
        function onRightPanelEdgesChanged() { root.readOthers() }
        function onRightPanelSpansChanged() { root.readOthers() }
    }
    // The panel it hangs under (the farthest-reaching one on this edge):
    // { edge, span } (span: its body's left and right, when it says them)
    readonly property var anchor: {
        if (cards.count === 0)
            return null
        let best = null
        for (const o of others) {
            const d = mirrored ? screenHeight - o.edge : o.edge
            if (best === null || d > best.edge)
                best = { edge: d, span: o.span }
        }
        return best
    }
    readonly property real othersEdge: anchor !== null ? anchor.edge : 0
    // Under a panel: off the bar, lined up with that panel's body
    readonly property bool detached: othersEdge > junction
    readonly property var span: detached && anchor.span ? anchor.span : null
    readonly property real wantTop: detached ? othersEdge + Theme.toastGap : junction
    // 0 on the bar, 1 hanging under a panel: the room from that panel and
    // the move to its left side follow this step, on the edge drawers'
    // closing time and curves; the panel's own edge is followed frame by
    // frame (it moves on its edge timeline), never through an animation
    // that would start again at every frame
    property real gapStep: detached ? 1 : 0
    Behavior on gapStep {
        enabled: cards.count > 0 && !Theme.reduceMotion
        NumberAnimation {
            duration: Theme.dur(Theme.motionEdgeClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.detached ? Theme.curveDecel : Theme.curveAccel
        }
    }
    // The panel's left side, kept while the pile goes back to the bar
    property real spanLeft: screenWidth - rowWidth
    onSpanChanged: {
        if (span)
            spanLeft = span.left
    }
    // The pile's box, from its left to the screen's edge: its own width
    // (attached to the bar) or the panel's body (a drawer of the right
    // edge too)
    readonly property real boxLeft: screenWidth - rowWidth + (spanLeft - (screenWidth - rowWidth)) * gapStep
    readonly property real boxWidth: screenWidth - boxLeft

    // Under a panel, only the cards that fit whole between its edge and the
    // end of the screen show (the others wait, counted in "e mais N", their
    // time stopped); none fits: the pile closes and they all wait. They come
    // back as the panel shrinks or closes. { show: [bool by row], waiting }
    readonly property real usefulBottom: screenHeight - Theme.gap
    // Also while the pile goes back to the bar (its top still on the way):
    // the ones that waited come in as there is room, never past the end
    readonly property bool fitting: detached || pileTop > junction + 0.5
    readonly property var fit: {
        const n = rows.count
        if (!fitting)
            return { show: [], waiting: 0, noMore: false }
        const top = detached ? wantTop : pileTop
        // A body too narrow for a card: none fits
        const narrow = detached && boxWidth - 2 * pad < minCardWidth
        const pass = reserve => {
            let y = top
            const show = []
            let waiting = 0
            for (let i = 0; i < n; i++) {
                const slot = rows.itemAt(i)
                if (!slot) {
                    show.push(true)
                    continue
                }
                if (slot.leaving) {
                    y += slot.rowHeight * slot.room
                    show.push(true)
                    continue
                }
                if (!narrow && waiting === 0 && y + slot.rowHeight <= usefulBottom - reserve) {
                    y += slot.rowHeight
                    show.push(true)
                } else {
                    show.push(false)
                    waiting++
                }
            }
            return { show: show, waiting: waiting }
        }
        const first = pass(0)
        if (first.waiting === 0 && NotificationState.moreCount === 0)
            return Object.assign(first, { noMore: false })
        // Room for "e mais N" too; if then not even one card fits, the card
        // shows and the line does not
        const second = pass(26)
        const shown = f => f.show.filter(x => x).length
        return shown(second) === 0 && shown(first) > 0 ? Object.assign(first, { noMore: true }) : Object.assign(second, { noMore: false })
    }
    readonly property int waiting: fit.waiting
    // Not one card fits: every card slides away and its room closes (the
    // pile closes as a drawer); they come back as there is room
    readonly property int minCardWidth: Theme.toastWidth - 2 * pad
    readonly property bool squeezed: detached && liveN > 0 && waiting >= liveN
    // Under the panel's edge as it moves, or on the bar's
    readonly property real pileTop: (detached ? othersEdge : junction) + Theme.toastGap * gapStep
    // (set when the first card is in place)
    property bool settled: false

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
    onMonitorNameChanged: {
        syncOverlay()
        readOthers()
    }
    // The overlay key in use: a monitor's name that comes late (or changes)
    // lets go of the old key, so no stale one keeps the screen "busy"
    property string overlayKey: ""
    function syncOverlay() {
        const key = monitorName !== "" ? "notificacoes:" + monitorName : ""
        if (overlayKey !== "" && overlayKey !== key)
            ShellState.setOverlay(overlayKey, false)
        overlayKey = key
        if (key !== "")
            ShellState.setOverlay(key, visible && !hidden && pileBottom > 0)
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
    readonly property alias maskItem: maskArea

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
    Component.onCompleted: {
        readOthers()
        sync()
    }

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
                    required property int index
                    required property int cardId
                    required property int count
                    required property bool leaving
                    // 0..1: its room in the pile; 1..0: off to the right
                    property real room: 1
                    property real out: 1
                    readonly property real rowHeight: toast.implicitHeight + 2 * root.pad
                    // From the box's left (in) to the screen's edge (out)
                    readonly property real leftX: root.boxLeft + (root.screenWidth - root.boxLeft) * out
                    // Under a panel with no room for it: waiting
                    // (a row the fit has not counted yet waits: it is new)
                    readonly property bool shows: !root.fitting || root.fit.show[index] === true
                    // Seen at least once (a card that only waited leaves at once)
                    property bool everShown: false
                    width: root.width
                    // (a card that stops fitting slides away and its room
                    // closes; it comes back with the normal way in)
                    height: rowHeight * room
                    // The card shows only inside its room: coming in, it
                    // unrolls as it slides, the shape and the column with it
                    clip: room < 0.999

                    ToastCard {
                        id: toast
                        x: (Theme.reduceMotion ? root.boxLeft : slot.leftX) + root.pad
                        y: root.pad
                        width: root.boxWidth - 2 * root.pad
                        opacity: Theme.reduceMotion ? 1 - slot.out : 1
                        cardId: slot.cardId
                        count: slot.count
                        // Its time runs only while the pile shows it
                        active: root.visible && !root.hidden && !slot.leaving && slot.shows
                        onExpired: NotificationState.dismissToast(slot.cardId)
                        transform: Scale {
                            origin.y: toast.height / 2
                            yScale: root.mirrored ? -1 : 1
                        }
                    }

                    function enter() {
                        everShown = true
                        wait.duration = Theme.dur(root.openBar())
                        comeIn.restart()
                    }
                    Component.onCompleted: {
                        // A new card's room opens with it (never all at once)
                        room = 0
                        if (!leaving && shows)
                            enter()
                    }
                    // No room for it any more: it slides away and its room
                    // closes, as when it leaves (but it stays, its time
                    // stopped); room again: it comes in
                    onShowsChanged: {
                        if (leaving)
                            return
                        if (shows) {
                            tuck.stop()
                            enter()
                        } else if (everShown) {
                            comeIn.stop()
                            tuck.restart()
                        } else {
                            room = 0
                        }
                    }
                    SequentialAnimation {
                        id: tuck
                        NumberAnimation {
                            target: slot; property: "out"; to: 1
                            duration: Theme.dur(Math.round(Theme.motionEdgeClose * (1 - Theme.edgePanelFrom)))
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveAccel
                        }
                        NumberAnimation {
                            target: slot; property: "room"; to: 0
                            duration: Theme.dur(Theme.motionEdgeClose)
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard
                        }
                    }
                    onLeavingChanged: {
                        if (leaving) {
                            comeIn.stop()
                            tuck.stop()
                            root.countLive()
                            if (everShown) {
                                goOut.restart()
                            } else {
                                // Never on the screen: gone, no slide, no room
                                out = 1
                                room = 0
                                drop.restart()
                            }
                        } else if (goOut.running) {
                            goOut.stop()
                            enter()
                        } else if (shows && !everShown) {
                            enter()
                        }
                    }
                    Timer {
                        id: drop
                        interval: 0
                        onTriggered: root.remove(slot.cardId)
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
                            // Its room opens in the same time as the slide, soft
                            // at both ends (also a slot taken back while its
                            // room was closing)
                            NumberAnimation {
                                target: slot; property: "room"; to: 1
                                duration: Theme.dur(Math.round(Theme.motionEdgeOpen * (1 - Theme.edgePanelFrom)))
                                easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard
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
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveStandard
                        }
                        ScriptAction { script: root.remove(slot.cardId) }
                    }
                }
            }

            // The ones that did not fit wait in the list
            Item {
                id: more
                width: root.width
                // (the list's ones, and the ones waiting for room here)
                readonly property int n: NotificationState.moreCount + root.waiting
                height: n > 0 && root.liveN > root.waiting && !root.fit.noMore ? 26 : 0
                visible: height > 0
                Text {
                    x: root.boxLeft + root.pad + 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: more.n === 1 ? "e mais 1" : `e mais ${more.n}`
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
            if (s) {
                // All out (waiting to come in, or its room closing after it
                // left): not in the shape, with motion reduced too
                const x = s.out >= 0.999 ? screenWidth : Theme.reduceMotion ? boxLeft : s.leftX
                out.push({ x: x, y: pileTop + s.y, h: s.height })
            }
        }
        if (more.height > 0) {
            const minX = out.length > 0 ? Math.min(...out.map(r => r.x)) : screenWidth
            out.push({ x: Math.max(minX, boxLeft), y: pileTop + more.y, h: more.height })
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
        : Math.min(attachRadius, Theme.radius * Math.max(0, Math.min(1, (screenWidth - firstShown.x) / Math.max(1, boxWidth * 0.3))))
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
    // (down to the rooms still open, a card's that left included, so the
    // strip below moves with them instead of jumping)
    // The room from the panel above closes with the last few px of the
    // pile, so the edge ends on the panel's own (no step when it goes)
    readonly property real pileBottom: cards.count > 0 && column.height > 0.5
        ? Math.max(outline.lowest, (detached ? othersEdge : junction) + column.height
                                   + Theme.toastGap * gapStep * Math.min(1, column.height / Theme.toastGap))
        : 0
    // Something of it on the screen (the overlay follows it)
    readonly property bool drawn: pileBottom > 0
    onDrawnChanged: syncOverlay()
    // Hidden only for a capture (Print, a recording), the pile still holds
    // its place: the strip keeps following its edge (it would jump up over
    // the card in the picture, and back down after)
    readonly property bool hiddenForCapture: CaptureState.open || CaptureState.recording || CaptureState.printing
    readonly property bool outOfPlace: !focusedHere || NotificationState.locked || (frame !== null && frame.out > 0)
    readonly property real stripEdge: visible && !outOfPlace && pileBottom > 0
                                      ? Math.round(mirrored ? screenHeight - pileBottom : pileBottom) : 0
    onStripEdgeChanged: ShellState.setRightPanelEdge(monitorName, stripEdge, edgeOwner)
    // A monitor gone with the pile showing: nothing of it stays
    Component.onDestruction: {
        ShellState.setRightPanelEdge(monitorName, 0, edgeOwner)
        if (overlayKey !== "")
            ShellState.setOverlay(overlayKey, false)
    }
}
