.pragma library

// Annotation tools of the capture: the tool list and how each stroke is
// painted on a Canvas 2D context. Ported from dms-screenshot-plus
// (lib/Tools.js, lib/Hit.js, lib/Renderer.js), cut down to the tools of
// these dotfiles and to coordinates local to one monitor.
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

// kind:
//   drag   two points, press and release: arrow, rect, line, mosaic
//   path   every point along the drag: pen, highlighter
//   click  one point: number
//   text   one point, then a text box takes over
// sizes: what the 4 widths (2/3/5/8) mean for the tool: line width, font
// size, marker radius or mosaic block.
var TOOLS = [
    { id: "arrow",       icon: "󰁔", label: "Seta",        key: "A", kind: "drag",  sizes: [2, 3, 5, 8] },
    { id: "rect",        icon: "󰝣", label: "Retângulo (Shift: cheio)", key: "R", kind: "drag",  sizes: [2, 3, 5, 8] },
    { id: "line",        icon: "󰍴", label: "Linha",       key: "L", kind: "drag",  sizes: [2, 3, 5, 8] },
    { id: "pen",         icon: "󰏫", label: "Caneta",      key: "P", kind: "path",  sizes: [2, 3, 5, 8] },
    { id: "highlighter", icon: "󰸱", label: "Marca-texto", key: "H", kind: "path",  sizes: [10, 16, 24, 32] },
    { id: "text",        icon: "󰊄", label: "Texto",       key: "T", kind: "text",  sizes: [16, 24, 32, 48] },
    { id: "number",      icon: "󰲠", label: "Números",     key: "N", kind: "click", sizes: [10, 14, 18, 24] },
    { id: "mosaic",      icon: "󰕰", label: "Mosaico (clique de novo: borrar)", key: "M", kind: "drag", sizes: [6, 12, 18, 28] }
]

var WIDTHS = [2, 3, 5, 8]
var ARROW_SPREAD = Math.PI / 7          // half-angle of the head
var ARROW_BASE = Math.cos(ARROW_SPREAD) // shaft ends on the head's base
var MAX_CANVAS_FONT_PX = 48             // larger text is scaled up; Qt's glyph cache degrades above this

function byId(id) {
    for (var i = 0; i < TOOLS.length; i++)
        if (TOOLS[i].id === id)
            return TOOLS[i]
    return null
}

function byKey(letter) {
    for (var i = 0; i < TOOLS.length; i++)
        if (TOOLS[i].key === letter)
            return TOOLS[i]
    return null
}

function kindOf(id) {
    var t = byId(id)
    return t ? t.kind : ""
}

// Size of a tool for the chosen width (2/3/5/8)
function sizeFor(id, width) {
    var t = byId(id)
    var i = WIDTHS.indexOf(width)
    return t ? t.sizes[i === -1 ? 1 : i] : width
}

// Normalised rectangle of a two-point stroke
function rectOf(stroke) {
    var p = stroke.points
    if (!p || p.length < 2)
        return { x: p && p[0] ? p[0].x : 0, y: p && p[0] ? p[0].y : 0, w: 0, h: 0 }
    var x0 = Math.min(p[0].x, p[1].x), y0 = Math.min(p[0].y, p[1].y)
    var x1 = Math.max(p[0].x, p[1].x), y1 = Math.max(p[0].y, p[1].y)
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
}

// Number markers show 1..N in creation order, so undoing one makes the
// next marker take its number again
function numbering(strokes) {
    var ids = []
    for (var i = 0; i < strokes.length; i++)
        if (strokes[i].tool === "number")
            ids.push(strokes[i].id)
    ids.sort(function (a, b) { return a - b })
    var map = {}
    for (var j = 0; j < ids.length; j++)
        map[ids[j]] = j + 1
    return map
}

function fontString(px, family, bold) {
    return (bold ? "bold " : "") + Math.round(px) + 'px "' + String(family).replace(/"/g, '\\"') + '"'
}

function drawArrowLike(ctx, x0, y0, x1, y1, width, withHead) {
    var dx = x1 - x0, dy = y1 - y0
    var len = Math.sqrt(dx * dx + dy * dy)
    if (len < 0.5)
        return
    var angle = Math.atan2(dy, dx)

    if (!withHead) {
        ctx.beginPath()
        ctx.moveTo(x0, y0)
        ctx.lineTo(x1, y1)
        ctx.stroke()
        return
    }

    var head = Math.max(15, width * 4)
    var shaft = Math.max(0, len - head * ARROW_BASE)
    ctx.beginPath()
    ctx.moveTo(x0, y0)
    ctx.lineTo(x0 + shaft * Math.cos(angle), y0 + shaft * Math.sin(angle))
    ctx.stroke()

    ctx.beginPath()
    ctx.moveTo(x1, y1)
    ctx.lineTo(x1 - head * Math.cos(angle - ARROW_SPREAD), y1 - head * Math.sin(angle - ARROW_SPREAD))
    ctx.lineTo(x1 - head * Math.cos(angle + ARROW_SPREAD), y1 - head * Math.sin(angle + ARROW_SPREAD))
    ctx.closePath()
    ctx.fill()
}

// cfg: { offsetX, offsetY, numbers ({ id: n }), font, ink (number digit
// color), highlightAlpha }. Mosaic and blur are not painted here: they are
// pieces of the frame (AnnotationLayer).
function drawStroke(ctx, s, cfg) {
    var pts = s.points || []
    if (pts.length === 0 || s.tool === "mosaic")
        return
    var ox = cfg.offsetX || 0, oy = cfg.offsetY || 0

    ctx.save()
    ctx.strokeStyle = s.color
    ctx.fillStyle = s.color
    ctx.lineWidth = Math.max(1, s.size)
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    switch (s.tool) {
    case "rect": {
        var r = rectOf(s)
        if (s.fill)
            ctx.fillRect(r.x + ox, r.y + oy, r.w, r.h)
        else
            ctx.strokeRect(r.x + ox, r.y + oy, r.w, r.h)
        break
    }
    case "line":
    case "arrow":
        if (pts.length >= 2)
            drawArrowLike(ctx, pts[0].x + ox, pts[0].y + oy, pts[pts.length - 1].x + ox, pts[pts.length - 1].y + oy,
                          s.size, s.tool === "arrow")
        break
    case "highlighter":
        ctx.globalAlpha = cfg.highlightAlpha || 0.35
        ctx.lineCap = "square"
        ctx.lineJoin = "miter"
        // fallthrough
    case "pen":
        ctx.beginPath()
        ctx.moveTo(pts[0].x + ox, pts[0].y + oy)
        if (pts.length === 1)
            ctx.lineTo(pts[0].x + ox + 0.01, pts[0].y + oy) // a tap still leaves a dot
        for (var i = 1; i < pts.length; i++)
            ctx.lineTo(pts[i].x + ox, pts[i].y + oy)
        ctx.stroke()
        break
    case "number": {
        var radius = Math.max(6, s.size)
        var cx = pts[0].x + ox, cy = pts[0].y + oy
        ctx.beginPath()
        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
        ctx.fill()
        var label = String((cfg.numbers && cfg.numbers[s.id]) || 1)
        var wanted = radius * 1.35
        var px = Math.min(MAX_CANVAS_FONT_PX, wanted)
        var extra = wanted / px
        ctx.fillStyle = cfg.ink || "black"
        ctx.font = fontString(px, cfg.font, true)
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.translate(cx, cy)
        ctx.scale(extra, extra)
        // "middle" centers the em box, not the digits, which sit ~15% high
        ctx.fillText(label, 0, px * 0.15)
        break
    }
    case "text": {
        var lines = String(s.text || "").split("\n")
        var lh = s.lineHeight || s.size * 1.3
        var fpx = Math.min(MAX_CANVAS_FONT_PX, s.size)
        var fscale = s.size / fpx
        ctx.font = fontString(fpx, cfg.font, false)
        ctx.textAlign = "left"
        ctx.textBaseline = "top"
        ctx.translate(pts[0].x + ox, pts[0].y + oy)
        ctx.scale(fscale, fscale)
        for (var li = 0; li < lines.length; li++)
            ctx.fillText(lines[li], 0, (li * lh) / fscale)
        break
    }
    }
    ctx.restore()
}

function drawAll(ctx, strokes, cfg) {
    var c = Object.assign({}, cfg, { numbers: numbering(strokes) })
    for (var i = 0; i < strokes.length; i++)
        drawStroke(ctx, strokes[i], c)
}
