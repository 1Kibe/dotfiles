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

    readonly property bool focusedHere: Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === monitorName
    readonly property bool hidden: !focusedHere || CaptureState.open || NotificationState.locked
    readonly property bool mirrored: Theme.barAtBottom
    readonly property bool overCapture: false

    // What the frame reads: the right end of the bar stretched to the edge
    readonly property string edgeSide: "right"
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
    Behavior on pileTop {
        enabled: cards.count > 0 && !Theme.reduceMotion
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
        ShellState.setOverlay("notificacoes:" + monitorName, visible && !hidden)
    }
    onHiddenChanged: ShellState.setOverlay("notificacoes:" + monitorName, visible && !hidden)

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
    function liveCount() {
        let n = 0
        for (let i = 0; i < cards.count; i++) {
            if (!cards.get(i).leaving)
                n++
        }
        return n
    }

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
    }
    function remove(id) {
        const i = indexOf(id)
        if (i >= 0 && cards.get(i).leaving)
            cards.remove(i)
        if (cards.count === 0)
            stretchClose.restart()
    }
    // A card started leaving: with no other one left, the bar's end goes
    // back once it is out
    function leaving() {
        if (liveCount() === 0)
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
                            root.leaving()
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
                        NumberAnimation {
                            target: slot; property: "out"; to: 0
                            duration: Theme.dur(Math.round(Theme.motionEdgeOpen * (1 - Theme.edgePanelFrom)))
                            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel
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
                height: NotificationState.moreCount > 0 && root.liveCount() > 0 ? 26 : 0
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
    // The concave corner on the bar grows as the first card comes in
    readonly property real topRadius: {
        const first = segments.length > 0 ? segments[0] : null
        return first ? Theme.radius * Math.max(0, Math.min(1, (screenWidth - first.x) / (rowWidth * 0.3))) : 0
    }
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
        y: root.mirrored ? root.screenHeight - root.outline.lowest : root.pileTop
        width: root.hidden ? 0 : root.screenWidth - root.leftmost
        height: root.hidden || root.outline.lowest <= root.pileTop ? 0 : root.outline.lowest - root.pileTop
    }

    // The minimized windows' strip slides out of the pile's way
    readonly property real stripEdge: visible && !hidden && outline.lowest > 0
                                      ? Math.round(mirrored ? screenHeight - outline.lowest : outline.lowest) : 0
    onStripEdgeChanged: ShellState.setRightPanelEdge(monitorName, stripEdge, edgeOwner)
    Component.onDestruction: ShellState.setRightPanelEdge(monitorName, 0, edgeOwner)
}
