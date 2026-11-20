import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.state
import "stripgeom.js" as Geom
import "stripmotion.js" as Motion
import "../control/lists.js" as Lists

// The minimized windows of one screen, on its right edge (inside the
// MinimizedStrip window, the screen's height). One piece that grows to the
// left: hidden (no window), the 5 px wire with a dot per window (7 and a
// dash past 8), the icons after 150 ms with the mouse on the edge, the
// names (with the ×) when the mouse holds on it; 300 ms after the mouse
// leaves it is the wire again. The first window makes the wire come out of
// the edge, the last one makes it go back in, as a drawer; reduce motion
// fades instead. A window just minimized opens it in icons for a moment.
// Wanting attention: the wire in the alert color. A click on a row brings
// the window back here; the middle button or the × closes it. Past the
// rows that fit, the last one is "+N", which opens the whole list.
// It slides below a bar panel reaching the edge and above a drawer from the
// bottom, shrinks, and hides when not even the least fits.
Item {
    id: root

    property string screenName: ""
    // This screen's minimized windows (MinimizeState.forMonitor)
    property var entries: []
    // The free part of the screen, top to bottom (the bar left out)
    property real areaTop: 0
    property real areaBottom: height
    // A panel reaching the edge from the top / a drawer from the bottom (0 none)
    property real topEdge: 0
    property real bottomEdge: 0
    // A bar panel is one of those edges (a drawer from the bottom never
    // makes the strip close anything)
    property bool panelInTheWay: topEdge > 0

    readonly property var m: ({
        wire: Theme.wireWidth, icons: Theme.minimizeIcons, names: Theme.minimizeNames,
        row: Theme.minimizeRow, margin: Theme.minimizeMargin, wireMin: Theme.minimizeWireMin,
        dot: Theme.minimizeDot, dotGap: Theme.minimizeDotGap, maxRows: Theme.minimizeMaxRows
    })

    // ── The levels (stripmotion.js) ──
    property string level: "hidden"
    // The whole list, scrolling, after a click on "+N"
    property bool all: false
    function apply(r) {
        for (const t of r.cancel) {
            if (t === "open") openTimer.stop()
            else if (t === "close") closeTimer.stop()
            else if (t === "hold") holdTimer.stop()
            else if (t === "flash") flashTimer.stop()
            else if (t === "room") {
                roomTimer.stop()
                afterCloseTimer.stop()
            }
        }
        if (r.timer) {
            if (r.timer.name === "open") openTimer.restart()
            else if (r.timer.name === "close") closeTimer.restart()
            else if (r.timer.name === "flash") flashTimer.restart()
        }
        level = r.level
        if (level !== "names")
            all = false
        if (level === "icons" && hovered)
            holdTimer.restart()
    }
    // The mouse on the edge, as the events said (the room's wait checks it)
    property bool pointerIn: false
    function send(event) {
        if (event === "enter" || event === "leave")
            pointerIn = event === "enter"
        const r = Motion.step(level, event)
        // Open only where the rows fit; else it stays the wire (no flash)
        if ((r.level === "icons" || r.level === "names") && level === "wire" && !fits("icons"))
            return
        apply(r)
    }
    function fits(lvl) {
        return Geom.place({
            areaTop: areaTop, areaBottom: areaBottom, topEdge: topEdge, bottomEdge: bottomEdge,
            gap: Theme.minimizeRadius, level: lvl, n: count
        }, m).visible
    }
    // Open over the screen: the minimize picture waits (it would be in it)
    readonly property bool openNow: level === "icons" || level === "names"
    onOpenNowChanged: MinimizeState.setStripOpen(screenName, openNow)
    Component.onDestruction: MinimizeState.setStripOpen(screenName, false)
    readonly property int count: entries.length
    onCountChanged: {
        if (count === 0) {
            roomTimer.stop()
            afterCloseTimer.stop()
        }
        send(count > 0 ? "filled" : "empty")
    }
    Component.onCompleted: send(count > 0 ? "filled" : "empty")

    readonly property bool hovered: hit.hovered
    onHoveredChanged: {
        if (!hovered) {
            roomTimer.stop()
            afterCloseTimer.stop()
        }
        send(hovered ? "enter" : "leave")
        if (hovered)
            for (const e of entries)
                if (e.attention && level === "wire")
                    MinimizeState.clearAttention(e.address)
    }
    Timer {
        id: openTimer
        interval: Motion.OPEN_MS
        onTriggered: {
            // A bar panel in the way: room first, and the icons wait for it
            // (the section folds; if still not enough for min(n, 4) rows,
            // the panel closes and the strip opens in the middle). The
            // panel never reopens by itself
            // (Room already there: open at once)
            if (root.panelInTheWay && !root.fits("icons")) {
                ShellState.requestRoom(root.screenName)
                roomTimer.restart()
                return
            }
            root.send("timer150")
        }
    }
    Timer {
        id: roomTimer
        // The section folds (its height and the panel's body, one after
        // the other) before the room is measured
        interval: Theme.dur(Theme.animNormal) + Theme.dur(Theme.motionPanelClose) + 120
        onTriggered: {
            if (!root.pointerIn || root.level !== "wire")
                return
            const g = Geom.place({
                areaTop: root.areaTop, areaBottom: root.areaBottom, topEdge: root.topEdge, bottomEdge: root.bottomEdge,
                gap: Theme.minimizeRadius, level: "icons", n: root.count
            }, root.m)
            if (!g.visible && root.panelInTheWay) {
                // The panel closes: the strip opens once it is out of the way
                ShellState.closePanelOn(root.screenName)
                afterCloseTimer.restart()
                return
            }
            root.send("timer150")
        }
    }
    Timer {
        id: afterCloseTimer
        interval: Theme.dur(Theme.motionPanelClose) + 120
        onTriggered: {
            if (root.pointerIn && root.level === "wire")
                root.send("timer150")
        }
    }
    Timer {
        id: closeTimer
        interval: Motion.CLOSE_MS
        onTriggered: root.send("timer300")
    }
    Timer {
        id: holdTimer
        interval: Theme.hoverDelay
        onTriggered: {
            if (root.hovered)
                root.send("hold")
        }
    }
    Timer {
        id: flashTimer
        interval: Theme.minimizeFlash
        onTriggered: {
            if (!root.hovered)
                root.send("flashEnd")
        }
    }
    // A window of this screen just minimized: open a moment in icons
    function flash(address) {
        if (!hovered && entries.some(e => e.address === address))
            send("flash")
    }
    Connections {
        target: MinimizeState
        function onMinimized(address) {
            Qt.callLater(() => root.flash(address))
        }
    }

    // ── Where it is ──
    readonly property var g: Geom.place({
        areaTop: areaTop, areaBottom: areaBottom, topEdge: topEdge, bottomEdge: bottomEdge,
        gap: Theme.minimizeRadius, level: level === "hidden" ? "wire" : level, n: count
    }, m)
    readonly property real wantW: level === "hidden" || !g.visible ? 0 : Geom.widthFor(level, m)
    readonly property bool attention: entries.some(e => e.attention)
    // Open with a window wanting attention: its icon pulses (about 1 s, 8
    // steps a second); the timer runs only then
    property real pulse: 1
    Timer {
        id: pulseTimer
        interval: Theme.minimizePulseStep
        repeat: true
        // Reduce motion: no pulse (only fading is allowed there)
        running: root.attention && (root.level === "icons" || root.level === "names") && root.pieceW > 0
                 && !Theme.reduceMotion
        property int phase: 0
        onTriggered: {
            phase = (phase + 1) % 8
            root.pulse = 0.4 + 0.6 * Math.abs(Math.cos(phase * Math.PI / 8))
        }
        onRunningChanged: {
            if (!running)
                root.pulse = 1
        }
    }

    // Animated (the drawer and the growing); reduce motion: the width at
    // once, and kept while the piece fades out
    property real keptW: 0
    onWantWChanged: {
        if (wantW > 0)
            keptW = wantW
    }
    property real fade: wantW > 0 ? 1 : 0
    Behavior on fade {
        NumberAnimation { duration: Theme.dur(Theme.motionPanelClose) }
    }
    readonly property real pieceW: Theme.reduceMotion ? (wantW > 0 ? wantW : fade > 0 ? keptW : 0) : animW
    property real animW: wantW
    Behavior on animW {
        enabled: !Theme.reduceMotion
        NumberAnimation {
            duration: Theme.dur(root.wantW > root.pieceW ? Theme.motionPanelOpen : Theme.motionPanelClose)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.wantW > root.pieceW ? Theme.curveDecel : Theme.curveAccel
        }
    }
    // The whole list after "+N": as tall as it needs, inside the free part
    readonly property real freeTop: Math.max(areaTop, topEdge > 0 ? topEdge + Theme.minimizeRadius : areaTop)
    readonly property real freeBottom: Math.min(areaBottom, bottomEdge > 0 ? bottomEdge - Theme.minimizeRadius : areaBottom)
    readonly property real allHeight: Math.max(0, Math.min(freeBottom - freeTop, 2 * Theme.minimizeMargin + count * Theme.minimizeRow))
    readonly property real wantTop: all ? Math.min(Math.max(freeTop, (areaTop + areaBottom) / 2 - allHeight / 2), freeBottom - allHeight)
                                        : g.top
    readonly property real wantH: all ? allHeight : g.visible ? g.height : 0
    // Following a panel or the drawer: in the same movement as theirs (no
    // animation of its own); changing level or count: animated
    property bool edgeMoving: false
    onTopEdgeChanged: {
        edgeMoving = true
        edgeTimer.restart()
    }
    onBottomEdgeChanged: {
        edgeMoving = true
        edgeTimer.restart()
    }
    Timer {
        id: edgeTimer
        interval: Theme.dur(Theme.animFast)
        onTriggered: root.edgeMoving = false
    }
    property real pieceTop: wantTop
    Behavior on pieceTop {
        enabled: !Theme.reduceMotion && !root.edgeMoving
        NumberAnimation { duration: Theme.dur(Theme.motionPanelOpen); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
    }
    property real pieceH: wantH
    Behavior on pieceH {
        enabled: !Theme.reduceMotion && !root.edgeMoving
        NumberAnimation { duration: Theme.dur(Theme.motionPanelOpen); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveDecel }
    }
    opacity: Theme.reduceMotion ? fade : 1

    // The part that takes the mouse: the piece, and with the wire a wider
    // invisible zone on the edge
    Item {
        id: hitArea
        readonly property real zone: root.level === "wire" ? Math.max(root.pieceW, Theme.minimizeHit) : root.pieceW
        x: root.width - zone
        y: root.pieceTop
        width: root.pieceW > 0 ? zone : 0
        height: root.pieceH
        HoverHandler {
            id: hit
        }
    }
    readonly property Item hitItem: hitArea

    // The rows: kept while the open piece fades back to the wire, and one
    // per window (by address), so a title change does not rebuild the row
    // under the mouse
    property int keptRows: 0
    readonly property int rowsNow: level === "icons" || level === "names" ? g.rows.shown : keptRows
    readonly property var byAddress: {
        const m = {}
        for (const e of entries)
            m[e.address] = e
        return m
    }
    ListModel {
        id: rowModel
    }
    function syncRows() {
        const want = (all ? entries : entries.slice(0, rowsNow)).map(e => e.address)
        for (let i = rowModel.count - 1; i >= 0; i--) {
            if (want[i] !== rowModel.get(i).addr)
                rowModel.remove(i)
        }
        for (let i = rowModel.count; i < want.length; i++)
            rowModel.append({ addr: want[i] })
    }
    onEntriesChanged: syncRows()
    onRowsNowChanged: {
        keptRows = rowsNow
        syncRows()
    }
    onAllChanged: syncRows()

    // ── The preview of the row under the mouse (names only) ──
    property var hoveredEntry: null
    property real hoveredY: 0
    MinimizedPreview {
        entry: root.level === "names" ? root.hoveredEntry : null
        x: root.width - root.pieceW - width - Theme.spacing
        y: Geom.cardTop(root.hoveredY, root.areaTop, root.areaBottom, height)
    }

    StripShape {
        anchors.fill: parent
        bodyWidth: root.pieceW
        bodyTop: root.pieceTop
        bodyHeight: root.pieceH
        fillColor: root.level === "wire" && root.attention ? Theme.alert : Theme.stripFill
    }

    // ── The dots (the wire) ──
    Column {
        readonly property var d: Geom.dotCount(root.count)
        x: root.width - root.pieceW / 2 - Theme.minimizeDot / 2
        y: root.pieceTop + (root.pieceH - height) / 2
        spacing: Theme.minimizeDotGap
        opacity: root.level === "wire" ? 1 : 0
        visible: opacity > 0 && root.pieceW > 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.dur(Theme.animFast) }
        }

        Repeater {
            model: parent.d.count

            Rectangle {
                required property int index
                width: Theme.minimizeDot
                height: Theme.minimizeDot
                radius: width / 2
                color: root.entries[index] && root.entries[index].attention ? Theme.yellow : Theme.accentLight
            }
        }
        // "More": a dash in the alert color
        Rectangle {
            visible: parent.d.more
            width: Theme.minimizeDot
            height: Theme.minimizeDot * 3
            radius: width / 2
            // The whole wire is in the alert color with attention
            color: root.attention ? Theme.fg : Theme.alert
        }
    }

    // ── The rows (icons, names) ──
    Flickable {
        id: rowsView
        x: root.width - root.pieceW
        y: root.pieceTop + Theme.minimizeMargin
        width: root.pieceW
        height: Math.max(0, root.pieceH - 2 * Theme.minimizeMargin)
        contentWidth: width
        contentHeight: rowsColumn.implicitHeight
        interactive: root.all && contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        opacity: root.level === "icons" || root.level === "names" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.dur(Theme.animFast) }
        }

        Column {
            id: rowsColumn
            width: rowsView.width

            Repeater {
                model: rowModel

                Item {
                    id: row
                    required property string addr
                    readonly property var modelData: root.byAddress[addr] ?? ({ address: addr, cls: "", title: "", attention: false })
                    readonly property string iconPath: /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(modelData.cls)
                        ? (Quickshell.iconPath(modelData.cls, true) || Quickshell.iconPath(modelData.cls.toLowerCase(), true)) : ""
                    width: rowsColumn.width
                    height: Theme.minimizeRow

                    Rectangle {
                        anchors.fill: parent
                        color: rowMouse.containsMouse || xMouse.containsMouse ? Theme.veil : Theme.clear
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            MinimizeState.clearAttention(row.modelData.address)
                            root.hoveredEntry = row.modelData
                            root.hoveredY = row.mapToItem(root, 0, row.height / 2).y
                        }
                        onExited: {
                            if (root.hoveredEntry && root.hoveredEntry.address === row.modelData.address)
                                root.hoveredEntry = null
                        }
                        onClicked: event => {
                            if (event.button === Qt.MiddleButton)
                                MinimizeState.close(row.modelData.address)
                            else
                                MinimizeState.restore(row.modelData.address, root.screenName)
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.minimizeMargin
                        anchors.rightMargin: Theme.minimizeMargin
                        spacing: Theme.spacing
                        layoutDirection: Qt.RightToLeft

                        Item {
                            Layout.preferredWidth: Theme.minimizeIcon
                            Layout.preferredHeight: Theme.minimizeIcon
                            opacity: row.modelData.attention ? root.pulse : 1
                            Image {
                                anchors.fill: parent
                                visible: row.iconPath !== ""
                                source: row.iconPath
                                sourceSize.width: Theme.minimizeIcon
                                sourceSize.height: Theme.minimizeIcon
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: row.iconPath === ""
                                text: String.fromCodePoint(0xF08C6)   // nf-md-application
                                textFormat: Text.PlainText
                                color: Theme.accentLight
                                font.family: Theme.font
                                font.pointSize: Theme.fontSize
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.level === "names"
                            text: Lists.trim(row.modelData.title !== "" ? row.modelData.title : row.modelData.cls)
                            textFormat: Text.PlainText
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignLeft
                            color: Theme.fg
                            font.family: Theme.font
                            font.pointSize: Theme.fontSize - 1
                        }
                        // The × (on the row under the mouse): closes it
                        Text {
                            visible: root.level === "names" && (rowMouse.containsMouse || xMouse.containsMouse)
                            text: String.fromCodePoint(0xF0156)   // nf-md-close
                            textFormat: Text.PlainText
                            color: Theme.gray
                            font.family: Theme.font
                            font.pointSize: Theme.fontSizeSmall
                            MouseArea {
                                id: xMouse
                                anchors.fill: parent
                                anchors.margins: -Theme.spacing / 2
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MinimizeState.close(row.modelData.address)
                            }
                        }
                    }
                }
            }
            // "+N": the whole list, with the names
            Item {
                visible: !root.all && root.g.rows.plus > 0
                width: rowsColumn.width
                height: Theme.minimizeRow
                Text {
                    anchors.centerIn: parent
                    text: `+${root.g.rows.plus}`
                    textFormat: Text.PlainText
                    color: Theme.fg2
                    font.family: Theme.font
                    font.pointSize: Theme.fontSizeSmall
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.all = true
                        root.apply({ level: "names", timer: null, cancel: [] })
                        root.all = true
                    }
                }
            }
        }
    }
}
