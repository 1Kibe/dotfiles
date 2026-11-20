import QtQuick
import qs.theme
import qs.state
import "layout.js" as Layout
import "../control/lists.js" as Lists

// What the overview shows on one screen (inside Overview's window): the
// areas' strip on top (AreaCard: the areas, "Minimizadas · N" when there
// is any, "+"), and in the middle the windows of the area shown, arranged
// by layout.js (WindowCard), scrolling when there are many. A click on an
// empty spot closes; a window goes to it; the mouse or a click on an area
// shows its windows; a double click goes to that area. Keys: arrows choose
// a window, Enter goes to it, Esc closes; typing does nothing.
Item {
    id: root

    property string screenName: ""
    // The shown area's windows: [{ id (address), title, appClass, x, y, w, h }],
    // positions relative to the screen
    property var windows: []
    // The strip: [{ area, ws, label, shown, rects: [{ x, y, w, h } 0..1] }]
    property var areas: []
    property int minimizedCount: 0
    // The "+": the new area after the strip's last one and its workspace
    // here; 0 none (no "+")
    property int plusArea: 0
    property int plusWs: 0
    // The middle shows the minimized windows instead (their card chosen)
    property bool showingMinimized: false
    Connections {
        target: OverviewState
        function onOpenChanged() {
            root.showingMinimized = false
        }
    }

    // A window card dropped at a point of the scene: on an area, moved
    // there; on "+", to the new area at the end; anywhere else, back in place
    function dropCard(id, at) {
        for (const c of strip.children) {
            if (c.kind === undefined || !c.visible || c.kind === "")
                continue
            const p = c.mapFromItem(null, at.x, at.y)
            if (p.x < 0 || p.y < 0 || p.x > c.width || p.y > c.height)
                continue
            const ws = c.kind === "plus" ? root.plusWs : c.ws
            return ws > 0 && OverviewState.moveWindow(id, ws)
        }
        return false
    }
    onMinimizedCountChanged: {
        if (minimizedCount === 0)
            showingMinimized = false
    }

    // The dragged card's copy, above the middle (which clips)
    property point dragGrab
    function startDrag(id, at, card) {
        frozen = windows
        dragId = id
        const local = card.mapFromItem(null, at.x, at.y)
        dragGrab = Qt.point(local.x, local.y)
        ghost.width = card.width
        ghost.height = card.height
        ghost.title = card.win.title || ""
        moveDrag(at)
    }
    function moveDrag(at) {
        const p = root.mapFromItem(null, at.x, at.y)
        ghost.x = p.x - dragGrab.x
        ghost.y = p.y - dragGrab.y
    }
    function endDrag(id, at) {
        dragId = ""
        frozen = []
        if (at.x >= 0)
            dropCard(id, at)
    }

    // The flight: 0 = each card where its window really is, 1 = in its
    // place; the strip and the veil fade with it. Reduce motion: no flight,
    // only the fade.
    property real progress: OverviewState.open ? 1 : 0
    Behavior on progress {
        // Locking: no flight back, it goes at once
        enabled: !OverviewState.locked
        NumberAnimation {
            duration: Theme.dur(OverviewState.open ? Theme.motionPanelOpen : Theme.motionPanelClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: OverviewState.open ? Theme.curveDecel : Theme.curveAccel
        }
    }
    // The flight's step for the positions (1 at once with reduce motion)
    readonly property real fly: Theme.reduceMotion ? 1 : progress
    // Flying back, the cards not chosen land first (Theme.overviewLead of
    // the way earlier) and the chosen one last, over them
    readonly property real flyOthers: Theme.reduceMotion ? 1 : OverviewState.open ? progress
        : Math.max(0, (progress - Theme.overviewLead) / (1 - Theme.overviewLead))

    readonly property real stripTop: Theme.overviewMargin / 2
    readonly property var useful: ({
        x: Theme.overviewMargin,
        y: 0,
        w: Math.max(0, width - 2 * Theme.overviewMargin),
        h: Math.max(0, height - stripTop - Theme.overviewStripHeight - 2 * Theme.overviewMargin)
    })
    // While a card is dragged the windows hold still (a title or focus
    // change would rebuild the middle under the mouse)
    property string dragId: ""
    property var frozen: []
    readonly property var liveWindows: dragId !== "" ? frozen : windows
    readonly property var arranged: Layout.arrange(liveWindows, useful, Theme.overviewGap, Theme.overviewCardMinHeight)
    readonly property var byId: {
        const m = {}
        for (const w of liveWindows)
            m[w.id] = w
        return m
    }
    readonly property var cardOf: {
        const m = {}
        for (const c of arranged.cards)
            m[c.id] = c
        return m
    }
    // The cards' model, by id: a card (and its capture) lives as long as
    // its window, whatever else changes
    ListModel {
        id: cardModel
    }
    function syncCards() {
        const want = showingMinimized ? [] : arranged.cards.map(c => c.id)
        for (let i = cardModel.count - 1; i >= 0; i--) {
            if (!want.includes(cardModel.get(i).cid))
                cardModel.remove(i)
        }
        const have = []
        for (let i = 0; i < cardModel.count; i++)
            have.push(cardModel.get(i).cid)
        for (const id of want) {
            if (!have.includes(id))
                cardModel.append({ cid: id })
        }
    }
    onArrangedChanged: syncCards()
    onShowingMinimizedChanged: syncCards()
    Component.onCompleted: syncCards()

    // ── The keyboard ──
    function moveChoice(dx, dy) {
        const cards = arranged.cards
        if (cards.length === 0)
            return
        let i = cards.findIndex(c => c.id === OverviewState.selected)
        if (i < 0) {
            OverviewState.select(cards[0].id)
            return
        }
        const c = cards[i]
        if (dx !== 0) {
            i = Math.max(0, Math.min(cards.length - 1, i + dx))
        } else {
            // The nearest card of the row above or below
            const cy = c.y + c.h / 2, cx = c.x + c.w / 2
            const other = cards.filter(o => dy < 0 ? o.y + o.h <= c.y : o.y >= c.y + c.h)
            if (other.length === 0)
                return
            const rowY = dy < 0 ? Math.max(...other.map(o => o.y)) : Math.min(...other.map(o => o.y))
            const row = other.filter(o => o.y === rowY)
            row.sort((a, b) => Math.abs(a.x + a.w / 2 - cx) - Math.abs(b.x + b.w / 2 - cx))
            i = cards.indexOf(row[0])
        }
        OverviewState.select(cards[i].id)
        // The chosen card on screen (the middle scrolls)
        const s = cards[i]
        if (s.y < middle.contentY)
            middle.contentY = s.y
        else if (s.y + s.h > middle.contentY + middle.height)
            middle.contentY = s.y + s.h - middle.height
    }
    function key(event) {
        if (event.key === Qt.Key_Escape)
            OverviewState.hide()
        else if (event.key === Qt.Key_Left)
            moveChoice(-1, 0)
        else if (event.key === Qt.Key_Right)
            moveChoice(1, 0)
        else if (event.key === Qt.Key_Up)
            moveChoice(0, -1)
        else if (event.key === Qt.Key_Down)
            moveChoice(0, 1)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && OverviewState.selected !== "")
            OverviewState.goTo(OverviewState.selected)
        else
            return false
        return true
    }

    // The veil over the screen
    Rectangle {
        anchors.fill: parent
        color: Theme.overviewVeil
        opacity: root.progress
    }

    // An empty spot: closes
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: OverviewState.hide()
    }

    // ── The strip ──
    // The strip's cards shrink so that all of them (and "+") fit the width
    readonly property int stripCount: areas.length + (minimizedCount > 0 ? 1 : 0)
    readonly property real stripCardWidth: Math.min(Math.round(Theme.overviewStripHeight * 16 / 10),
        (width - 2 * Theme.overviewMargin - Theme.overviewStripHeight - stripCount * Theme.overviewGap / 2) / Math.max(1, stripCount))
    Row {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.stripTop
        opacity: root.progress
        height: Theme.overviewStripHeight
        spacing: Theme.overviewGap / 2

        Repeater {
            model: root.areas

            AreaCard {
                required property var modelData
                width: root.stripCardWidth
                height: strip.height
                label: modelData.label
                rects: modelData.rects
                shown: modelData.shown && !root.showingMinimized
                kind: "area"
                ws: modelData.ws
                // Passing over the strip while dragging a card never changes
                // the middle (a drop outside a target puts it back in place)
                onEntered: {
                    if (root.dragId !== "")
                        return
                    root.showingMinimized = false
                    OverviewState.showArea(root.screenName, modelData.ws)
                }
                onClicked: {
                    root.showingMinimized = false
                    OverviewState.showArea(root.screenName, modelData.ws)
                }
                onDoubleClicked: OverviewState.goToArea(modelData.area)
            }
        }
        AreaCard {
            visible: root.minimizedCount > 0
            width: root.stripCardWidth
            height: strip.height
            label: `Minimizadas · ${root.minimizedCount}`
            shown: root.showingMinimized
            onClicked: {
                if (OverviewState.open)
                    root.showingMinimized = true
            }
        }
        AreaCard {
            visible: root.plusArea > 0 && root.plusWs > 0
            width: height
            height: strip.height
            label: "+"
            dashed: true
            kind: "plus"
            // The new area, empty, and close
            onClicked: OverviewState.goToArea(root.plusArea)
        }
    }

    // ── The middle ──
    Flickable {
        id: middle
        x: 0
        y: root.stripTop + Theme.overviewStripHeight + Theme.overviewMargin
        width: root.width
        height: root.useful.h + Theme.overviewMargin
        contentWidth: width
        contentHeight: Math.max(height, root.arranged.height)
        interactive: root.arranged.height > root.useful.h
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // An empty spot of the middle closes too
        MouseArea {
            width: middle.contentWidth
            height: middle.contentHeight
            acceptedButtons: Qt.LeftButton
            onClicked: OverviewState.hide()
        }
        Repeater {
            model: cardModel

            WindowCard {
                id: wc
                required property string cid
                readonly property var place: root.cardOf[cid] ?? ({ x: 0, y: 0, w: 0, h: 0 })
                readonly property var from: root.byId[cid] ?? place
                // From where the window is on the screen (in the middle's
                // coordinates) to the card's place
                readonly property bool landsLast: OverviewState.landing === cid
                readonly property real f: landsLast ? root.fly : root.flyOthers
                z: landsLast ? 1 : 0
                x: from.x + (place.x - from.x) * f
                y: from.y - middle.y + middle.contentY + (place.y - (from.y - middle.y + middle.contentY)) * f
                width: from.w + (place.w - from.w) * f
                height: from.h + (place.h - from.h) * f
                targetW: place.w
                targetH: place.h
                opacity: dragging ? Theme.overviewDragFade : Theme.reduceMotion ? root.progress : 1
                win: root.byId[cid] ?? ({ title: "", appClass: "" })
                chosen: OverviewState.selected === cid
                onPicked: OverviewState.goTo(cid)
                onCloseClicked: OverviewState.closeWindow(cid)
                onDragStarted: at => root.startDrag(cid, at, wc)
                onDragMoved: at => root.moveDrag(at)
                onDropped: at => root.endDrag(cid, at)
            }
        }
    }
    // The minimized windows, as a list: a click brings one back here
    Column {
        anchors.centerIn: middle
        visible: root.showingMinimized
        spacing: 6

        Repeater {
            model: root.showingMinimized ? ShellState.minimized : []

            Rectangle {
                required property var modelData
                width: Theme.overviewListWidth
                height: Theme.listRowHeight + Theme.spacing / 2
                radius: Theme.radius
                color: minMouse.containsMouse ? Theme.bg1 : Theme.bg

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.spacing
                    width: parent.width - 2 * Theme.spacing
                    text: Lists.trim(String(modelData.title || ""))
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                }
                MouseArea {
                    id: minMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Through OverviewState, which checks the address and the state
                    onClicked: OverviewState.restoreMinimized(String(modelData.address || ""))
                }
            }
        }
    }
    Text {
        anchors.centerIn: middle
        // Also when the windows are there but not measured yet (a window
        // just opened has no size): the cards are what counts
        visible: root.arranged.cards.length === 0 && !root.showingMinimized
        text: "Nenhuma janela nesta área"
        textFormat: Text.PlainText
        color: Theme.fg4
        font.family: Theme.font
        font.pointSize: Theme.fontSize + 1
    }

    // A dragged card's copy: above the middle and the strip, unclipped
    Rectangle {
        id: ghost
        property string title: ""
        visible: root.dragId !== ""
        z: 20
        radius: Theme.radius
        color: Theme.bg
        border.width: Theme.focusWidth
        border.color: Theme.focusRing
        opacity: Theme.overviewGhostOpacity

        Text {
            x: Theme.spacing
            y: Theme.spacing / 2
            width: parent.width - 2 * Theme.spacing
            text: Lists.trim(ghost.title)
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
    }
}
