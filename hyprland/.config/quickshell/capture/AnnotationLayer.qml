// Annotation layer of one monitor of the capture: what goes into the PNG
// (the selected part of the frozen frame, mosaics and blurs made from the
// frame's own pixels, and the strokes) and the text box used while typing,
// which is never exported. Ported from dms-screenshot-plus
// (AnnotationLayer.qml), adapted to CaptureState and the Theme here.
//
// Portions: MIT License
//
// Copyright (c) 2026 pcmid
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import QtQuick
import QtQuick.Effects
import qs.theme
import qs.state
import "tools.js" as Tools

Item {
    id: annot

    required property var win          // the monitor's overlay: selection and scale
    required property Item frameItem   // the frozen frame

    readonly property alias exportItem: exportRoot
    readonly property bool editingText: textSession !== null

    // Stroke being drawn (never in the undo history until it is done)
    property string activeTool: ""
    property var activePoints: []
    property bool activeFill: false
    property var textSession: null     // { x, y, size }

    readonly property var frameRegions: CaptureState.strokes.filter(s => s.tool === "mosaic")

    function colorValue() {
        return String(Theme[CaptureState.color])
    }

    // Local coordinates of this monitor
    function begin(x, y) {
        const tool = CaptureState.tool
        const kind = Tools.kindOf(tool)
        if (kind === "text") {
            beginText(x, y)
            return
        }
        if (kind === "click") {
            CaptureState.pushStroke({ tool: tool, color: colorValue(), size: Tools.sizeFor(tool, CaptureState.width), points: [{ x: x, y: y }] })
            return
        }
        activeTool = tool
        const p = { x: x, y: y }
        activePoints = kind === "drag" ? [p, p] : [p]
        activeCanvas.requestPaint()
    }

    function update(x, y, shift) {
        if (activePoints.length === 0)
            return
        const p = { x: x, y: y }
        const pts = activePoints.slice()
        if (Tools.kindOf(activeTool) === "drag")
            pts[1] = p
        else
            pts.push(p)
        activePoints = pts
        activeFill = shift
        activeCanvas.requestPaint()
    }

    // A click without dragging (up to ~3 px) leaves nothing: only numbers and
    // text are made by a click
    function end(shift) {
        const pts = activePoints
        const tool = activeTool
        activePoints = []
        activeTool = ""
        activeCanvas.requestPaint()
        if (pts.length === 0)
            return
        let minX = pts[0].x, maxX = pts[0].x, minY = pts[0].y, maxY = pts[0].y
        for (const p of pts) {
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y)
        }
        if (maxX - minX <= 3 && maxY - minY <= 3)
            return
        CaptureState.pushStroke({
            tool: tool, color: colorValue(), size: Tools.sizeFor(tool, CaptureState.width), points: pts,
            fill: tool === "rect" && shift, blur: tool === "mosaic" && CaptureState.blurMode
        })
    }

    function preview() {
        if (activePoints.length === 0 || activeTool === "mosaic")
            return null
        return { id: CaptureState.nextId, tool: activeTool, color: colorValue(), fill: activeTool === "rect" && activeFill,
                 size: Tools.sizeFor(activeTool, CaptureState.width), points: activePoints }
    }

    // ── Text ──
    function beginText(x, y) {
        if (textSession)
            commitText()
        textSession = { x: x, y: y, size: Tools.sizeFor("text", CaptureState.width) }
        textEdit.text = ""
        textEdit.forceActiveFocus()
    }

    function commitText() {
        const s = textSession
        if (!s)
            return
        const text = textEdit.text
        const lineHeight = textEdit.contentHeight / Math.max(1, textEdit.lineCount)
        endText()
        if (text.trim() !== "")
            CaptureState.pushStroke({ tool: "text", color: colorValue(), size: s.size, points: [{ x: s.x, y: s.y }],
                                      text: text, lineHeight: lineHeight })
    }

    function cancelText() {
        if (textSession)
            endText()
    }

    function endText() {
        textSession = null
        textEdit.text = ""
        win.focusKeys()
    }

    // ── What is exported ──
    Item {
        id: exportRoot

        x: annot.win.selX
        y: annot.win.selY
        width: Math.max(1, annot.win.selW)
        height: Math.max(1, annot.win.selH)
        clip: true
        visible: annot.win.hasSel

        // The frame, sampled at its own resolution (not at the on-screen size)
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: annot.frameItem
            sourceRect: Qt.rect(annot.win.selX, annot.win.selY, annot.win.selW, annot.win.selH)
            textureSize: Qt.size(Math.max(1, Math.round(annot.win.selW * annot.win.outScale)),
                                 Math.max(1, Math.round(annot.win.selH * annot.win.outScale)))
            hideSource: false
        }

        // Mosaic: the frame region rendered at (size / block) pixels and
        // scaled up without smoothing. Blur: the same region, blurred hard.
        // Both are made of the frame's pixels, so they go into the PNG.
        Repeater {
            model: annot.frameRegions

            Item {
                id: region

                required property var modelData
                readonly property var r: Tools.rectOf(modelData)
                readonly property real block: Math.max(2, modelData.size)

                x: r.x - annot.win.selX
                y: r.y - annot.win.selY
                width: Math.max(1, r.w)
                height: Math.max(1, r.h)
                clip: true

                ShaderEffectSource {
                    id: piece
                    anchors.fill: parent
                    sourceItem: annot.frameItem
                    sourceRect: Qt.rect(region.r.x, region.r.y, Math.max(1, region.r.w), Math.max(1, region.r.h))
                    textureSize: region.modelData.blur
                                 ? Qt.size(Math.max(1, Math.ceil(region.r.w / 4)), Math.max(1, Math.ceil(region.r.h / 4)))
                                 : Qt.size(Math.max(1, Math.ceil(region.r.w / region.block)), Math.max(1, Math.ceil(region.r.h / region.block)))
                    smooth: region.modelData.blur
                    mipmap: false
                }
                MultiEffect {
                    visible: region.modelData.blur
                    anchors.fill: parent
                    source: piece
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1.0
                    blurMax: Theme.blurRadius
                }
            }
        }

        // Finished strokes. Window sized, so their coordinates do not depend
        // on the selection (resizing it never moves them)
        Canvas {
            id: bakedCanvas
            // Cooperative, as in dms-screenshot-plus: with the default strategy
            // every export after the first opening came out empty
            renderStrategy: Canvas.Cooperative
            x: -annot.win.selX
            y: -annot.win.selY
            width: annot.win.width
            height: annot.win.height

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                Tools.drawAll(ctx, CaptureState.strokes, { font: Theme.font, ink: String(Theme.bgHard), highlightAlpha: Theme.highlightAlpha })
            }

            Connections {
                target: CaptureState
                function onStrokesChanged() {
                    bakedCanvas.requestPaint()
                }
            }
        }

        // The stroke being drawn: the only thing repainted while dragging
        Canvas {
            id: activeCanvas
            renderStrategy: Canvas.Cooperative
            x: -annot.win.selX
            y: -annot.win.selY
            width: annot.win.width
            height: annot.win.height
            visible: annot.activePoints.length > 0

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const s = annot.preview()
                if (!s)
                    return
                const numbers = Tools.numbering(CaptureState.strokes)
                Tools.drawStroke(ctx, s, { font: Theme.font, ink: String(Theme.bgHard), highlightAlpha: Theme.highlightAlpha, numbers: numbers })
            }
        }

        // Mosaic or blur being dragged out
        Rectangle {
            readonly property var r: annot.activeTool === "mosaic" && annot.activePoints.length >= 2
                                     ? Tools.rectOf({ points: annot.activePoints }) : null
            visible: r !== null
            x: r ? r.x - annot.win.selX : 0
            y: r ? r.y - annot.win.selY : 0
            width: r ? r.w : 0
            height: r ? r.h : 0
            color: Theme.alpha(Theme.fg, 0.15)
            border.width: 1
            border.color: Theme.fg
        }
    }

    // ── Text box while typing (never exported) ──
    Item {
        id: textBox
        readonly property int pad: 4
        visible: annot.textSession !== null
        x: annot.textSession ? annot.textSession.x - pad : 0
        y: annot.textSession ? annot.textSession.y - pad : 0
        width: textEdit.contentWidth + pad * 2 + 4
        height: textEdit.contentHeight + pad * 2

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bgHard, 0.25)
            border.color: Theme.accentLight
            border.width: 1
            radius: 2
        }

        TextEdit {
            id: textEdit
            x: textBox.pad
            y: textBox.pad
            width: Math.max(8, contentWidth + 4)
            font.family: Theme.font
            font.pixelSize: annot.textSession ? annot.textSession.size : 24
            color: Theme[CaptureState.color]
            wrapMode: TextEdit.NoWrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            cursorVisible: activeFocus

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    annot.cancelText()
                    event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                    // Enter places the text; Shift+Enter makes a new line
                    if (inputMethodComposing)
                        Qt.inputMethod.commit()
                    Qt.callLater(annot.commitText)
                    event.accepted = true
                }
            }
        }
    }
}
