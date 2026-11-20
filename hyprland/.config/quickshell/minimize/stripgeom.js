.pragma library

// The minimized strip's geometry (minimize/StripBody). Plain JS: read by
// the shell and by the tests. m: the Theme's measures { wire, icons, names,
// row, margin, wireMin, dot, dotGap, maxRows }.

// How many rows show for n windows when `fit` rows fit: at most maxRows;
// when they do not all fit, the last place is "+N"
function rows(n, fit, maxRows) {
    const cap = Math.max(0, Math.min(fit, maxRows))
    if (n <= cap)
        return { shown: n, plus: 0 }
    const shown = Math.max(0, cap - 1)
    return { shown: shown, plus: n - shown }
}

function widthFor(level, m) {
    return level === "wire" ? m.wire : level === "icons" ? m.icons : level === "names" ? m.names : 0
}

// The wire's dots: one per window up to 8; with more, 7 and a dash
function dotCount(n) {
    return n <= 8 ? { count: Math.max(0, n), more: false } : { count: 7, more: true }
}

// The height the strip asks for at a level, with n windows and `lines`
// rows (shown plus the "+N" one)
function heightFor(level, n, lines, m) {
    if (level === "wire") {
        const d = dotCount(n)
        // The dash ("more") is three dots tall
        const dots = d.count + (d.more ? 1 : 0)
        const tall = d.count * m.dot + (d.more ? 3 * m.dot : 0)
        return Math.max(m.wireMin, 2 * m.margin + tall + Math.max(0, dots - 1) * m.dotGap)
    }
    if (level === "icons" || level === "names")
        return 2 * m.margin + lines * m.row
    return 0
}

// Where the strip goes on the edge: centered in the free part of the
// screen (from areaTop to areaBottom, the bar left out), below a panel
// reaching the edge (topEdge, 0 none) and above a drawer from the bottom
// (bottomEdge, 0 none), with `gap` between. It shrinks to the rows that fit
// and hides when not even the minimum fits (the wire's height; min(n, 4)
// rows open). Returns { top, height, rows: { shown, plus }, visible }.
function place(p, m) {
    const top0 = Math.max(p.areaTop, p.topEdge > 0 ? p.topEdge + p.gap : p.areaTop)
    const bottom0 = Math.min(p.areaBottom, p.bottomEdge > 0 ? p.bottomEdge - p.gap : p.areaBottom)
    const room = Math.max(0, bottom0 - top0)
    let r = { shown: 0, plus: 0 }
    let h
    if (p.level === "wire") {
        h = heightFor("wire", p.n, 0, m)
        if (h > room)
            return { top: top0, height: 0, rows: r, visible: false }
    } else if (p.level === "icons" || p.level === "names") {
        const fit = Math.floor((room - 2 * m.margin) / m.row)
        if (fit < Math.min(p.n, 4))
            return { top: top0, height: 0, rows: r, visible: false }
        r = rows(p.n, fit, m.maxRows)
        h = heightFor(p.level, p.n, r.shown + (r.plus > 0 ? 1 : 0), m)
    } else {
        return { top: (p.areaTop + p.areaBottom) / 2, height: 0, rows: r, visible: false }
    }
    // Centered in the whole free part, pushed down or up by the obstacles
    const mid = (p.areaTop + p.areaBottom) / 2
    let top = Math.round(mid - h / 2)
    top = Math.max(top, top0)
    top = Math.min(top, bottom0 - h)
    return { top: top, height: h, rows: r, visible: true }
}

// The preview card next to a row: at the row, kept inside the free part
function cardTop(anchorY, areaTop, areaBottom, cardHeight) {
    return Math.max(areaTop, Math.min(anchorY - cardHeight / 2, areaBottom - cardHeight))
}
