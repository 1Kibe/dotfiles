.pragma library

// The outline of the minimized strip's piece on the right edge: one shape
// for the wire and for the open piece, so it changes without a jump while
// the piece grows. Each end (top and bottom) is a concave curve from the
// screen's edge, a straight piece along the body's top (bottom), and the
// outer corner down to the body's side.
// - The wire (p 0): one long curve, concave then convex, from the edge
//   reach px before the body to 4 px into it, across the whole width (the
//   cubic (E, T-R) (E, T-0.4R) (E-w, T-0.55R) (E-w, T+4), split in two at
//   its middle; the straight piece has no length).
// - Open (p 1): the panels' corners, the concave one and the outer one
//   with the Theme's radius (each reaching (1 + s) times it, sharing the
//   width so the outline never turns back on itself).
// In between every point goes from one to the other with p. Points are
// [dx, dy]: dx from the edge into the screen, dy from the body's top down.

function lerp(a, b, p) {
    return [a[0] + (b[0] - a[0]) * p, a[1] + (b[1] - a[1]) * p]
}
function mid(a, b) {
    return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]
}

// The wire's long curve on width w (reach r along the edge, depth d into
// the body), split at its middle: [start, c1, c2, joint, joint, c3, c4, end]
function wireEnd(w, r, d) {
    const p0 = [0, -r], p1 = [0, -0.4 * r], p2 = [w, -0.55 * r], p3 = [w, d]
    const q1 = mid(p0, p1), m12 = mid(p1, p2), r2 = mid(p2, p3)
    const q2 = mid(q1, m12), r1 = mid(m12, r2), j = mid(q2, r1)
    return [p0, q1, q2, j, j, r1, r2, p3]
}
// The panels' corners on width w: the concave one reaching f, the outer
// one reaching o (k: where their handles sit, a share of the reach)
var HANDLE = 0.36
function panelEnd(w, f, o) {
    const k = HANDLE
    return [[0, -f], [0, -f * k], [f * k, 0], [f, 0], [w - o, 0], [w - o * k, 0], [w, o * k], [w, o]]
}
// The corners' radii as the panels have them (theme/corners.js reach:
// (1 + s) r), within the body: the outer one at most half the width and
// height, the concave one sharing the width with it
function radii(w, h, radius, s, grow) {
    const ro = Math.max(0, Math.min(radius, w / (2 * (1 + s)), h / (2 * (1 + s))))
    const rf = Math.max(0, Math.min(radius * grow, h / (2 * (1 + s)), w / (1 + s) - ro))
    return { rf: rf, ro: ro }
}
// The top end at width w and height h; p from the wire (0) to open (1)
function topEnd(w, h, p, m) {
    const grow = Math.min(1, w / m.wire / 0.3)
    const r = m.reach * Math.min(1, w / m.wire)
    const d = Math.min(m.depth, h / 2)
    const k = radii(w, h, m.radius, m.s, grow)
    const a = wireEnd(w, r, d), b = panelEnd(w, k.rf * (1 + m.s), k.ro * (1 + m.s))
    const q = Math.max(0, Math.min(1, p))
    return a.map((pt, i) => lerp(pt, b[i], q))
}
// p for a width: 0 at the wire, 1 at the icons' width
function openShare(w, m) {
    return m.icons > m.wire ? Math.max(0, Math.min(1, (w - m.wire) / (m.icons - m.wire))) : 1
}
function num(v) {
    return String(Math.round(v * 1000) / 1000)
}
// The SVG path: the edge at x = E, the body from top t, height h, width w
function path(E, t, h, w, m) {
    if (!(w > 0 && h > 0))
        return ""
    const e = topEnd(w, h, openShare(w, m), m)
    const b = t + h
    const T = pt => num(E - pt[0]) + " " + num(t + pt[1])
    const B = pt => num(E - pt[0]) + " " + num(b - pt[1])
    return "M " + T(e[0])
         + " C " + T(e[1]) + " " + T(e[2]) + " " + T(e[3])
         + " L " + T(e[4])
         + " C " + T(e[5]) + " " + T(e[6]) + " " + T(e[7])
         + " L " + B(e[7])
         + " C " + B(e[6]) + " " + B(e[5]) + " " + B(e[4])
         + " L " + B(e[3])
         + " C " + B(e[2]) + " " + B(e[1]) + " " + B(e[0])
         + " Z"
}
