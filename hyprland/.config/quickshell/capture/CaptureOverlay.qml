import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state
import "tools.js" as Tools

// Print: one full screen layer per monitor. In the "select" phase each one
// freezes its own monitor (one ScreencopyView frame, kept in memory) and
// dims it; the selection stays clear, with handles and its size in
// physical pixels. The capture bar sits on the focused monitor.
//   Área: drag (and resize by the handles, move by dragging inside)
//   Janela: the window under the mouse lights up, a click takes it
//   Tela: a click takes the whole monitor
// Then the annotation bar: drawing inside the selection with the chosen
// tool (AnnotationLayer); Ctrl+Z / Ctrl+Shift+Z undo and redo, letters pick
// a tool. Enter / Ctrl+C copies and saves, Ctrl+S only saves, Esc closes.
Scope {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win

                required property var modelData
                readonly property string name: modelData.name
                readonly property var info: CaptureState.monitors[name] || null
                readonly property real outScale: info ? info.scale : 1
                readonly property real originX: info ? info.x : 0
                readonly property real originY: info ? info.y : 0
                readonly property bool isFocus: name === CaptureState.focusName
                // Editor of a quick print (the card's pencil): only the focused
                // monitor, the picture instead of the frozen screen
                readonly property bool editing: CaptureState.purpose === "edit"
                readonly property bool shown: CaptureState.open && (CaptureState.phase === "select" || CaptureState.phase === "choose")
                                              && (!editing || isFocus)
                readonly property bool selectPhase: shown && CaptureState.phase === "select"
                readonly property bool frozenPhase: selectPhase && !editing
                // Until the frame is in, the window stays clear: nothing of it may end up in the frame
                // A frame is only taken once this overlay is fully clear on screen
                // (armed), and each opening takes a new one: the overlay shows up
                // only with that frame, so it can never end up inside it
                property bool armed: false
                readonly property Item frame: editing ? editFrame : frozen
                readonly property bool ready: editing ? editImage.status === Image.Ready
                                              : !frozenPhase || (armed && frozen.hasContent)
                // Pixels of the PNG per logical point: the monitor scale, or the
                // picture's own size in the editor (it keeps its resolution)
                readonly property real pixelScale: editing && editImage.width > 0 ? editImage.implicitWidth / editImage.width : outScale
                property real readyAt: 0
                // First free line under the capture bar and its hint (top edge elsewhere)
                readonly property real topFree: captureBar.visible ? captureBar.y + captureBar.height + 36 : 8
                onReadyChanged: readyAt = ready ? Date.now() : 0
                property bool closing: false

                // Selection, in this window's logical coordinates
                property real selX: 0
                property real selY: 0
                property real selW: 0
                property real selH: 0
                readonly property bool hasSel: CaptureState.selOwner === name && selW >= 2 && selH >= 2
                // Window or monitor under the mouse (Janela / Tela)
                property var hover: null

                screen: modelData
                visible: shown || closing
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: Theme.clear
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-capture"
                WlrLayershell.keyboardFocus: shown && isFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                onShownChanged: {
                    if (shown) {
                        closing = false
                        fadeOut.stop()
                        content.opacity = 0
                        content.opacity = Qt.binding(() => win.ready ? 1 : 0)
                        clearSelection()
                        keys.forceActiveFocus()
                    } else if (visible) {
                        closing = true
                        fadeOut.restart()
                    }
                }
                onFrozenPhaseChanged: {
                    clearSelection()
                    armed = false
                    if (frozenPhase)
                        arm.restart()
                }

                Timer {
                    id: arm
                    interval: 100     // a few frames for the clear overlay to reach the screen
                    onTriggered: win.armed = true
                }

                SequentialAnimation {
                    id: fadeOut
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
                    ScriptAction { script: win.closing = false }
                }

                function focusKeys() {
                    keys.forceActiveFocus()
                }

                function clearSelection() {
                    selW = 0
                    selH = 0
                    hover = null
                }

                // Physical pixel grid: a selection never cuts a pixel in half
                function snap(v) {
                    return Math.round(v * outScale) / outScale
                }

                function setSel(x, y, w, h) {
                    const x0 = Math.max(0, Math.min(snap(x), width))
                    const y0 = Math.max(0, Math.min(snap(y), height))
                    const x1 = Math.max(0, Math.min(snap(x + w), width))
                    const y1 = Math.max(0, Math.min(snap(y + h), height))
                    selX = Math.min(x0, x1)
                    selY = Math.min(y0, y1)
                    selW = Math.abs(x1 - x0)
                    selH = Math.abs(y1 - y0)
                    CaptureState.selOwner = name
                }

                // Topmost window on this monitor under a point (local coordinates)
                function windowAt(px, py) {
                    const gx = px + originX
                    const gy = py + originY
                    for (const w of CaptureState.windows) {
                        if (w.monitor === name && gx >= w.x && gx < w.x + w.w && gy >= w.y && gy < w.y + w.h)
                            return { x: w.x - originX, y: w.y - originY, w: w.w, h: w.h }
                    }
                    return null
                }

                // The selection at native resolution: grabToImage's size is
                // logical and Qt multiplies it by the window's pixel ratio,
                // which differs from the monitor scale when it is fractional
                function exportSelection(copy) {
                    if (!hasSel)
                        return
                    if (annot.editingText)
                        annot.commitText()
                    exportDelay.copy = copy
                    exportDelay.restart()   // let the canvases repaint first
                }

                Timer {
                    id: exportDelay
                    property bool copy
                    interval: 40
                    onTriggered: win.grabNow(copy)
                }

                function grabNow(copy) {
                    // The frame is not in yet, or only just (its texture may still
                    // be on its way): try again shortly
                    if (!ready || Date.now() - readyAt < 150) {
                        exportDelay.restart()
                        return
                    }
                    const d = win.devicePixelRatio || 1
                    // OCR reads small letters better twice as big; PPM is quick to
                    // write even for the whole screen
                    const ocr = CaptureState.purpose === "ocr"
                    const k = ocr ? 2 : 1
                    const w = Math.max(1, Math.round(selW * pixelScale * k / d))
                    const h = Math.max(1, Math.round(selH * pixelScale * k / d))
                    const tmp = `${CaptureState.tmpDir}/${ocr ? "ocr" : "shot"}-${Date.now()}.${ocr ? "ppm" : "png"}`
                    // The frame must stay until the grab is done: close only then
                    const ok = annot.exportItem.grabToImage(result => {
                        if (!result.saveToFile(tmp))
                            CaptureState.toast("󰀦", ocr ? "Não deu para ler o texto" : "Não deu para salvar o print", "")
                        else if (ocr)
                            CaptureState.runOcr(tmp)
                        else
                            CaptureState.finishPhoto(tmp, copy)
                        CaptureState.close()
                    }, Qt.size(w, h))
                    if (!ok) {
                        CaptureState.toast("󰀦", "Não deu para salvar o print", "")
                        CaptureState.close()
                    }
                }

                Connections {
                    target: CaptureState
                    function onExportRequested(copy) {
                        if (win.hasSel)
                            win.exportSelection(copy)
                    }
                }

                // ── Editor: the picture, fitted under the bar with room for the
                // annotation bar below it; the selection is the whole picture ──
                Item {
                    id: editFrame
                    anchors.fill: parent
                    visible: win.editing && win.shown

                    Image {
                        id: editImage
                        readonly property real natW: implicitWidth / win.outScale
                        readonly property real natH: implicitHeight / win.outScale
                        readonly property real k: natW > 0 ? Math.min(1, (win.width - 120) / natW,
                                                                     (win.height - Theme.barHeight - Theme.gap - 150) / natH) : 1
                        source: win.editing && win.shown ? `file://${CaptureState.editFile}` : ""
                        cache: false
                        smooth: true
                        width: natW * k
                        height: natH * k
                        x: Math.round((win.width - width) / 2)
                        y: Math.round(Theme.barHeight + Theme.gap + 20)
                        // The selection follows the picture's place on screen (its size
                        // is only known a moment after it loads)
                        function syncSelection() {
                            if (status !== Image.Ready || !win.editing || width <= 0)
                                return
                            win.selX = x
                            win.selY = y
                            win.selW = width
                            win.selH = height
                            CaptureState.selOwner = win.name
                        }
                        onStatusChanged: syncSelection()
                        onXChanged: syncSelection()
                        onYChanged: syncSelection()
                        onWidthChanged: syncSelection()
                        onHeightChanged: syncSelection()
                    }
                }

                // ── Frozen frame (memory only) ──
                // The source goes off between openings and comes back once the
                // overlay is clear, so each opening takes a new frame
                ScreencopyView {
                    id: frozen
                    anchors.fill: parent
                    captureSource: win.frozenPhase && win.armed ? win.modelData : null
                    live: false     // one frame; live would capture this overlay too
                    paintCursor: false
                    visible: win.frozenPhase
                }

                Item {
                    id: content
                    anchors.fill: parent
                    opacity: win.ready ? 1 : 0
                    Behavior on opacity {
                        // Fades in; hiding (waiting for a new frame) is instant
                        enabled: !win.closing && win.ready
                        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
                    }

                    // ── Dim outside the selection (or the hovered window/monitor) ──
                    readonly property rect hole: win.hasSel ? Qt.rect(win.selX, win.selY, win.selW, win.selH)
                                                : win.hover ? Qt.rect(win.hover.x, win.hover.y, win.hover.w, win.hover.h)
                                                : Qt.rect(0, 0, 0, 0)
                    Rectangle {   // above
                        x: 0; y: 0; width: win.width; height: content.hole.y
                        color: Theme.dim
                    }
                    Rectangle {   // below
                        x: 0; y: content.hole.y + content.hole.height
                        width: win.width; height: win.height - y
                        color: Theme.dim
                    }
                    Rectangle {   // left
                        x: 0; y: content.hole.y; width: content.hole.x; height: content.hole.height
                        color: Theme.dim
                    }
                    Rectangle {   // right
                        x: content.hole.x + content.hole.width; y: content.hole.y
                        width: win.width - x; height: content.hole.height
                        color: Theme.dim
                    }

                    // Hovered window or monitor
                    Rectangle {
                        visible: !win.hasSel && win.hover !== null
                        x: win.hover ? win.hover.x : 0
                        y: win.hover ? win.hover.y : 0
                        width: win.hover ? win.hover.w : 0
                        height: win.hover ? win.hover.h : 0
                        color: Theme.clear
                        border.width: 2
                        border.color: Theme.accentLight
                    }

                    // What is exported (frame piece, mosaics, strokes) and the text box
                    AnnotationLayer {
                        id: annot
                        anchors.fill: parent
                        win: win
                        frameItem: win.frame
                    }

                    // ── Mouse: select, move, resize; draw inside the selection ──
                    MouseArea {
                        id: picker
                        anchors.fill: parent
                        enabled: win.selectPhase
                        hoverEnabled: true
                        cursorShape: containsMouse && inside(mouseX, mouseY)
                                     ? (CaptureState.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor)
                                     : CaptureState.pickMode === "area" ? Qt.CrossCursor : Qt.PointingHandCursor

                        property real startX
                        property real startY
                        property string drag: ""      // "new" | "draw" | ""

                        function inside(x, y) {
                            return win.hasSel && x >= win.selX && x <= win.selX + win.selW
                                   && y >= win.selY && y <= win.selY + win.selH
                        }

                        onPositionChanged: mouse => {
                            if (pressed && drag === "new") {
                                win.setSel(startX, startY, mouse.x - startX, mouse.y - startY)
                            } else if (pressed && drag === "draw") {
                                annot.update(mouse.x, mouse.y, mouse.modifiers & Qt.ShiftModifier)
                            } else if (!pressed && !win.hasSel) {
                                if (CaptureState.pickMode === "window")
                                    win.hover = win.windowAt(mouse.x, mouse.y)
                                else if (CaptureState.pickMode === "screen")
                                    win.hover = { x: 0, y: 0, w: win.width, h: win.height }
                            }
                        }
                        onExited: {
                            if (!win.hasSel)
                                win.hover = null
                        }
                        onPressed: mouse => {
                            startX = mouse.x
                            startY = mouse.y
                            if (inside(mouse.x, mouse.y) && (CaptureState.kind === "photo" || win.editing)
                                    && CaptureState.purpose !== "ocr") {
                                // Inside the selection the chosen tool draws
                                drag = "draw"
                                annot.begin(mouse.x, mouse.y)
                            } else if (win.editing || CaptureState.strokes.length > 0 || CaptureState.pickMode !== "area") {
                                // An annotated selection stays; Janela/Tela pick by click
                                drag = ""
                            } else {
                                drag = "new"
                                win.hover = null
                                win.setSel(mouse.x, mouse.y, 0, 0)
                            }
                        }
                        onReleased: mouse => {
                            if (drag === "new" && (win.selW < 2 || win.selH < 2))
                                win.clearSelection()   // an empty or 1 px selection is ignored
                            else if (drag === "new" && CaptureState.purpose === "ocr")
                                CaptureState.exportRequested(true)   // OCR reads the area as soon as it is let go
                            else if (drag === "draw")
                                annot.end(mouse.modifiers & Qt.ShiftModifier)
                        }
                        onClicked: mouse => {
                            if (drag !== "" || win.editing || CaptureState.strokes.length > 0)
                                return
                            if (CaptureState.pickMode === "window") {
                                const w = win.windowAt(mouse.x, mouse.y)
                                if (w)
                                    win.setSel(w.x, w.y, w.w, w.h)
                            } else if (CaptureState.pickMode === "screen") {
                                win.setSel(0, 0, win.width, win.height)
                            }
                        }
                    }

                    // ── Selection frame, handles and size ──
                    Rectangle {
                        visible: win.hasSel
                        x: win.selX - 1
                        y: win.selY - 1
                        width: win.selW + 2
                        height: win.selH + 2
                        color: Theme.clear
                        border.width: 1
                        border.color: Theme.fg
                    }

                    Repeater {
                        // Corners and sides: which edges each handle moves
                        model: [
                            { h: -1, v: -1 }, { h: 0, v: -1 }, { h: 1, v: -1 },
                            { h: -1, v: 0 }, { h: 1, v: 0 },
                            { h: -1, v: 1 }, { h: 0, v: 1 }, { h: 1, v: 1 }
                        ]

                        Rectangle {
                            id: handle

                            required property var modelData
                            readonly property int s: Theme.handleSize

                            visible: win.hasSel && CaptureState.pickMode === "area" && !win.editing
                            x: win.selX + (modelData.h + 1) / 2 * win.selW - s / 2
                            y: win.selY + (modelData.v + 1) / 2 * win.selH - s / 2
                            width: s
                            height: s
                            radius: 2
                            color: Theme.fg
                            border.width: 1
                            border.color: Theme.bgHard

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: handle.modelData.h === 0 ? Qt.SizeVerCursor
                                             : handle.modelData.v === 0 ? Qt.SizeHorCursor
                                             : handle.modelData.h === handle.modelData.v ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                                property rect from
                                onPressed: from = Qt.rect(win.selX, win.selY, win.selW, win.selH)
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return
                                    const p = mapToItem(content, mouse.x, mouse.y)
                                    let x0 = from.x, y0 = from.y, x1 = from.x + from.width, y1 = from.y + from.height
                                    if (handle.modelData.h < 0) x0 = p.x
                                    if (handle.modelData.h > 0) x1 = p.x
                                    if (handle.modelData.v < 0) y0 = p.y
                                    if (handle.modelData.v > 0) y1 = p.y
                                    win.setSel(x0, y0, x1 - x0, y1 - y0)
                                }
                            }
                        }
                    }

                    // Size in physical pixels, above the selection (inside if no room)
                    Rectangle {
                        visible: win.hasSel
                        x: win.selX
                        y: win.selY - height - 6 >= win.topFree ? win.selY - height - 6 : win.selY + 6
                        width: sizeText.implicitWidth + 12
                        height: sizeText.implicitHeight + 6
                        radius: 6
                        color: Theme.stripFill

                        Text {
                            id: sizeText
                            anchors.centerIn: parent
                            text: `${Math.round(win.selW * win.pixelScale)} × ${Math.round(win.selH * win.pixelScale)}`
                            color: Theme.text
                            font.family: Theme.monoFont
                            font.pointSize: Theme.fontSize - 2
                        }
                    }

                    // After a selection: the annotation bar, under it (above if no room)
                    // Under the selection; above it if there is no room below; inside
                    // it, at the bottom, when there is room on neither side (Tela,
                    // a maximized window). Never over the capture bar.
                    AnnotateBar {
                        visible: win.hasSel && CaptureState.purpose !== "ocr" && !(picker.pressed && picker.drag !== "")
                        readonly property real hint: 34      // its own hint shows under it
                        readonly property bool fitsBelow: win.selY + win.selH + 10 + height + hint <= win.height
                        readonly property bool fitsAbove: win.selY - 10 - height >= win.topFree
                        x: Math.max(8, Math.min(win.selX + win.selW / 2 - width / 2, win.width - width - 8))
                        y: fitsBelow ? win.selY + win.selH + 10
                           : fitsAbove ? win.selY - height - 10
                           : Math.max(win.topFree, win.selY + win.selH - height - hint - 16)
                    }

                    // ── The capture bar, on the focused monitor ──
                    CaptureBar {
                        id: captureBar
                        visible: win.isFocus && !win.editing
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.barHeight + Theme.gap
                    }
                }

                // ── Keys (only the focused monitor has the keyboard) ──
                Item {
                    id: keys
                    focus: true
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        const shift = event.modifiers & Qt.ShiftModifier
                        if (event.key === Qt.Key_Escape) {
                            CaptureState.close()
                        } else if (ctrl && event.key === Qt.Key_Z) {
                            if (shift)
                                CaptureState.redo()
                            else
                                CaptureState.undo()
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (CaptureState.phase === "choose")
                                CaptureState.startCountdown()
                            else
                                CaptureState.exportRequested(true)
                        } else if (ctrl && event.key === Qt.Key_C) {
                            CaptureState.exportRequested(true)
                        } else if (ctrl && event.key === Qt.Key_S) {
                            CaptureState.exportRequested(false)
                        } else if (!ctrl && event.text.length === 1 && Tools.byKey(event.text.toUpperCase())) {
                            CaptureState.chooseTool(Tools.byKey(event.text.toUpperCase()).id)
                        } else {
                            return
                        }
                        event.accepted = true
                    }
                }
            }
        }
    }
}
