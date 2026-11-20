import QtQuick
import qs.theme
import qs.state
import "layout.js" as Layout

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

    // The flight: 0 = each card where its window really is, 1 = in its
    // place; the strip and the veil fade with it. Reduce motion: no flight,
    // only the fade.
    property real progress: OverviewState.open ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: Theme.dur(OverviewState.open ? Theme.motionPanelOpen : Theme.motionPanelClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: OverviewState.open ? Theme.curveDecel : Theme.curveAccel
        }
    }
    // The flight's step for the positions (1 at once with reduce motion)
    readonly property real fly: Theme.reduceMotion ? 1 : progress

    readonly property real stripTop: Theme.overviewMargin / 2
    readonly property var useful: ({
        x: Theme.overviewMargin,
        y: 0,
        w: Math.max(0, width - 2 * Theme.overviewMargin),
        h: Math.max(0, height - stripTop - Theme.overviewStripHeight - 2 * Theme.overviewMargin)
    })
    readonly property var arranged: Layout.arrange(windows, useful, Theme.overviewGap, Theme.overviewCardMinHeight)
    readonly property var byId: {
        const m = {}
        for (const w of windows)
            m[w.id] = w
        return m
    }

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
                width: Math.round(height * 16 / 10)
                height: strip.height
                label: modelData.label
                rects: modelData.rects
                shown: modelData.shown
                onEntered: OverviewState.showArea(root.screenName, modelData.ws)
                onClicked: OverviewState.showArea(root.screenName, modelData.ws)
                onDoubleClicked: OverviewState.goToArea(modelData.area)
            }
        }
        AreaCard {
            visible: root.minimizedCount > 0
            width: Math.round(height * 16 / 10)
            height: strip.height
            label: `Minimizadas · ${root.minimizedCount}`
        }
        AreaCard {
            width: Math.round(height * 10 / 10)
            height: strip.height
            label: "+"
            dashed: true
            onClicked: OverviewState.newArea()
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
            model: root.arranged.cards

            WindowCard {
                required property var modelData
                readonly property var real: root.byId[modelData.id] ?? ({ x: modelData.x, y: modelData.y, w: modelData.w, h: modelData.h })
                // From where the window is on the screen (in the middle's
                // coordinates) to the card's place
                x: real.x + (modelData.x - real.x) * root.fly
                y: real.y - middle.y + middle.contentY + (modelData.y - (real.y - middle.y + middle.contentY)) * root.fly
                width: real.w + (modelData.w - real.w) * root.fly
                height: real.h + (modelData.h - real.h) * root.fly
                opacity: Theme.reduceMotion ? root.progress : 1
                win: root.byId[modelData.id] ?? ({ title: "", appClass: "" })
                chosen: OverviewState.selected === modelData.id
                onPicked: OverviewState.goTo(modelData.id)
            }
        }
    }
    Text {
        anchors.centerIn: middle
        visible: root.windows.length === 0
        text: "Nenhuma janela nesta área"
        textFormat: Text.PlainText
        color: Theme.fg4
        font.family: Theme.font
        font.pointSize: Theme.fontSize + 1
    }
}
