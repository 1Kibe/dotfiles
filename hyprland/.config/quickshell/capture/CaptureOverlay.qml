import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.state

// Print: one full screen layer per monitor. In the "select" phase each one
// freezes its own monitor (one ScreencopyView frame, kept in memory) and
// dims it; the selection stays clear, with handles and its size in
// physical pixels. The capture bar sits on the focused monitor.
//   Área: drag (and resize by the handles, move by dragging inside)
//   Janela: the window under the mouse lights up, a click takes it
//   Tela: a click takes the whole monitor
// Enter / Ctrl+C copies and saves, Ctrl+S only saves, Esc closes.
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
                readonly property bool shown: CaptureState.open && (CaptureState.phase === "select" || CaptureState.phase === "choose")
                readonly property bool frozenPhase: CaptureState.open && CaptureState.phase === "select"
                // Until the frame is in, the window stays clear: nothing of it may end up in the frame
                readonly property bool ready: !frozenPhase || frozen.hasContent
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
                        content.opacity = Qt.binding(() => win.ready ? 1 : 0)
                        clearSelection()
                        keys.forceActiveFocus()
                    } else if (visible) {
                        closing = true
                        fadeOut.restart()
                    }
                }
                onFrozenPhaseChanged: clearSelection()

                SequentialAnimation {
                    id: fadeOut
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: Theme.animFast; easing.type: Easing.InCubic }
                    ScriptAction { script: win.closing = false }
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
                    const d = win.devicePixelRatio || 1
                    const w = Math.max(1, Math.round(selW * outScale / d))
                    const h = Math.max(1, Math.round(selH * outScale / d))
                    const tmp = `${CaptureState.tmpDir}/shot-${Date.now()}.png`
                    // The frame must stay until the grab is done: close only then
                    const ok = exportItem.grabToImage(result => {
                        if (result.saveToFile(tmp))
                            CaptureState.finishPhoto(tmp, copy)
                        else
                            CaptureState.toast("󰀦", "Não deu para salvar o print", "")
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

                // ── Frozen frame (memory only) ──
                ScreencopyView {
                    id: frozen
                    anchors.fill: parent
                    captureSource: win.frozenPhase && win.visible ? win.modelData : null
                    live: false     // one frame; live would capture this overlay too
                    paintCursor: false
                    visible: win.frozenPhase
                }

                // What gets exported: the selected part of the frame, sampled at
                // the frame's own resolution. Decorations are not inside it.
                Item {
                    id: exportItem
                    x: win.selX
                    y: win.selY
                    width: Math.max(1, win.selW)
                    height: Math.max(1, win.selH)
                    visible: win.hasSel

                    ShaderEffectSource {
                        anchors.fill: parent
                        sourceItem: frozen
                        sourceRect: Qt.rect(win.selX, win.selY, win.selW, win.selH)
                        textureSize: Qt.size(Math.max(1, Math.round(win.selW * win.outScale)), Math.max(1, Math.round(win.selH * win.outScale)))
                        hideSource: false
                    }
                }

                Item {
                    id: content
                    anchors.fill: parent
                    opacity: win.ready ? 1 : 0
                    Behavior on opacity {
                        enabled: !win.closing
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

                    // ── Mouse: select, move, resize ──
                    MouseArea {
                        id: picker
                        anchors.fill: parent
                        enabled: win.frozenPhase
                        hoverEnabled: true
                        cursorShape: CaptureState.mode === "area" ? Qt.CrossCursor : Qt.PointingHandCursor

                        property real startX
                        property real startY
                        property string drag: ""      // "new" | "move"
                        property rect from

                        onPositionChanged: mouse => {
                            if (pressed && drag === "new") {
                                win.setSel(startX, startY, mouse.x - startX, mouse.y - startY)
                            } else if (pressed && drag === "move") {
                                const nx = Math.max(0, Math.min(from.x + mouse.x - startX, win.width - from.width))
                                const ny = Math.max(0, Math.min(from.y + mouse.y - startY, win.height - from.height))
                                win.setSel(nx, ny, from.width, from.height)
                            } else if (!pressed && !win.hasSel) {
                                if (CaptureState.mode === "window")
                                    win.hover = win.windowAt(mouse.x, mouse.y)
                                else if (CaptureState.mode === "screen")
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
                            if (CaptureState.mode !== "area") {
                                drag = ""
                                return
                            }
                            const inside = win.hasSel && mouse.x >= win.selX && mouse.x <= win.selX + win.selW
                                           && mouse.y >= win.selY && mouse.y <= win.selY + win.selH
                            if (inside) {
                                drag = "move"
                                from = Qt.rect(win.selX, win.selY, win.selW, win.selH)
                            } else {
                                drag = "new"
                                win.hover = null
                                win.setSel(mouse.x, mouse.y, 0, 0)
                            }
                        }
                        onReleased: {
                            if (drag === "new" && (win.selW < 2 || win.selH < 2))
                                win.clearSelection()   // an empty or 1 px selection is ignored
                            drag = ""
                        }
                        onClicked: mouse => {
                            if (CaptureState.mode === "window") {
                                const w = win.windowAt(mouse.x, mouse.y)
                                if (w)
                                    win.setSel(w.x, w.y, w.w, w.h)
                            } else if (CaptureState.mode === "screen") {
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

                            visible: win.hasSel && CaptureState.mode === "area"
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
                        y: win.selY >= height + 6 ? win.selY - height - 6 : win.selY + 6
                        width: sizeText.implicitWidth + 12
                        height: sizeText.implicitHeight + 6
                        radius: 6
                        color: Theme.stripFill

                        Text {
                            id: sizeText
                            anchors.centerIn: parent
                            text: `${Math.round(win.selW * win.outScale)} × ${Math.round(win.selH * win.outScale)}`
                            color: Theme.text
                            font.family: Theme.monoFont
                            font.pointSize: Theme.fontSize - 2
                        }
                    }

                    // After a selection: save / copy (Tarefa 2 puts the annotation bar here)
                    Rectangle {
                        id: actions
                        visible: win.hasSel && !picker.pressed
                        readonly property bool below: win.selY + win.selH + height + 12 <= win.height
                        x: Math.max(8, Math.min(win.selX + win.selW - width, win.width - width - 8))
                        y: below ? win.selY + win.selH + 10 : Math.max(8, win.selY - height - 10)
                        width: actionRow.implicitWidth + 12
                        height: Theme.captureButtonHeight + 12
                        radius: Theme.pillRadius
                        color: Theme.stripFill

                        Row {
                            id: actionRow
                            anchors.centerIn: parent
                            spacing: 4

                            CaptureButton {
                                icon: "󰆓"
                                label: "Salvar"
                                onPressed: CaptureState.exportRequested(false)
                            }
                            CaptureButton {
                                icon: "󰆏"
                                label: "Copiar"
                                active: true
                                onPressed: CaptureState.exportRequested(true)
                            }
                        }
                    }

                    // ── The capture bar, on the focused monitor ──
                    CaptureBar {
                        visible: win.isFocus
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
                        if (event.key === Qt.Key_Escape) {
                            CaptureState.close()
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (CaptureState.phase === "choose")
                                CaptureState.startCountdown()
                            else
                                CaptureState.exportRequested(true)
                        } else if (ctrl && event.key === Qt.Key_C) {
                            CaptureState.exportRequested(true)
                        } else if (ctrl && event.key === Qt.Key_S) {
                            CaptureState.exportRequested(false)
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
