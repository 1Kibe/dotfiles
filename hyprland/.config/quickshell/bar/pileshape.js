.pragma library
.import "../theme/corners.js" as Corners

// The shape of the notifications' pile (bar/NotificationToasts): plain JS,
// read by the shell and by the tests. Coordinates are the frame's with the
// bar on top (the caller mirrors them with the bar on the bottom). The
// pile hangs on the screen's right edge, x = W; each row is { x, y, h, r }:
// its left edge (W when it is all off the screen), its top and height, and
// its right edge (r, W when left out). A column whose right edge stays off
// the screen's edge (under a panel set in from it) rounds its two right
// corners, more the farther it is.
// Rows that touch one another make one column, drawn as one closed path,
// clockwise like the panels' shapes (bar/AttachedShape): from the top, down
// the screen's edge, along the bottom, up the left side with a step at
// every change of width, back to the top. A column that starts on the bar's
// edge (junction) meets it with a concave corner of radius topR; any other
// top and every bottom take convex corners. Every corner is a continuous
// one (theme/corners.js) whose reach never passes half the step it turns
// nor half a row's height.

function reachToRadius(reach, s) {
    return Math.max(0, reach) / (1 + s)
}

// The rows on the screen, top first, in columns of touching rows
function rightOf(r, W) {
    return typeof r.r === "number" ? Math.min(W, r.r) : W
}
function columns(rows, W) {
    const segs = rows.filter(r => r.x < rightOf(r, W) - 0.5 && r.h > 0.5).slice().sort((a, b) => a.y - b.y)
    const out = []
    for (const s of segs) {
        const col = out[out.length - 1]
        const last = col ? col[col.length - 1] : null
        if (last && s.y - (last.y + last.h) < 0.5)
            col.push(s)
        else
            out.push([s])
    }
    return out
}

// One column's path. W: its right edge; top: { attached, r } (r: the
// concave corner's radius when attached, else the convex one's); botR: the
// bottom corner's radius; rightR: the right corners' (0 on the screen's edge)
function columnPath(W, col, top, botR, R, s, rightR) {
    const first = col[0]
    const last = col[col.length - 1]
    const ye = last.y + last.h
    const rr = rightR > 0 ? Math.min(rightR, reachToRadius(first.h / 2, s), reachToRadius((W - first.x) / 2, s),
                                     reachToRadius(last.h / 2, s), reachToRadius((W - last.x) / 2, s)) : 0
    let d = ""
    // Start where the top meets the right edge (attached: at the far end
    // of the concave corner, on the bar's edge)
    const ra = top.attached ? Corners.reach(top.r, s) : 0
    if (rr > 0) {
        d += top.attached ? `M ${first.x - ra} ${first.y} ` : `M ${first.x} ${first.y} `
        d += Corners.corner(W, first.y, 1, 0, 0, 1, rr, s)
        // Down the right side, its bottom corner, to the bottom-left corner
        d += Corners.corner(W, ye, 0, 1, -1, 0, rr, s)
    } else {
        d += top.attached ? `M ${first.x - ra} ${first.y} L ${W} ${first.y} ` : `M ${W} ${first.y} `
        // Down the screen's edge, along the bottom to the bottom-left corner
        d += `L ${W} ${ye} `
    }
    const rb = Math.min(botR, reachToRadius(last.h / 2, s), reachToRadius((W - last.x - (rr > 0 ? Corners.reach(rr, s) : 0)) / 2, s))
    d += Corners.corner(last.x, ye, -1, 0, 0, -1, rb, s)
    // Up the left side: a step where the width changes
    for (let i = col.length - 1; i > 0; i--) {
        const n = col[i]          // the lower row
        const c = col[i - 1]      // the upper one
        const y = n.y
        const dx = c.x - n.x
        if (Math.abs(dx) < 0.5)
            continue
        const r = Math.min(R, reachToRadius(Math.abs(dx) / 2, s), reachToRadius(c.h / 2, s), reachToRadius(n.h / 2, s))
        const dir = dx > 0 ? 1 : -1
        d += Corners.corner(n.x, y, 0, -1, dir, 0, r, s)
        d += Corners.corner(c.x, y, dir, 0, 0, -1, r, s)
    }
    // The top-left corner: concave into the bar's edge, or convex
    if (top.attached)
        d += Corners.corner(first.x, first.y, 0, -1, -1, 0, top.r, s)
    else
        d += Corners.corner(first.x, first.y, 0, -1, 1, 0, top.r, s)
    return d + "Z "
}

// The whole pile: { path, lowest, attached }. junction: the bar's edge; R:
// the corners' radius; topR: the concave corner's radius now (it grows as
// the first card comes in); s: the corners' smoothing
function outline(W, rows, junction, R, topR, s) {
    const cols = columns(rows, W)
    let d = ""
    let lowest = 0
    let attached = false
    cols.forEach((col, i) => {
        const first = col[0]
        const last = col[col.length - 1]
        // The column's right edge, and how much its right corners round
        const Wc = Math.max(...col.map(r => rightOf(r, W)))
        const rightR = Math.max(0, Math.min(R, W - Wc))
        const above = i > 0 ? cols[i - 1][cols[i - 1].length - 1] : null
        const gapTop = Math.max(0, first.y - (above ? above.y + above.h : junction))
        const below = cols[i + 1]
        const gapBot = below ? Math.max(0, below[0].y - (last.y + last.h)) : 1e9
        let top
        if (i === 0 && gapTop < 0.5) {
            attached = true
            top = { attached: true, r: Math.max(0, Math.min(topR, reachToRadius(Wc - first.x, s))) }
        } else {
            top = { attached: false, r: Math.max(0, Math.min(R, 2 * gapTop, reachToRadius(first.h / 2, s), reachToRadius((Wc - first.x) / 2, s))) }
        }
        d += columnPath(Wc, col, top, Math.min(R, 2 * gapBot), R, s, rightR)
        lowest = Math.max(lowest, last.y + last.h)
    })
    return { path: d, lowest: lowest, attached: attached }
}
