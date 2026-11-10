.pragma library

// Smoothed ("continuous") corners: the round corner of a quarter circle
// jumps from curvature 0 on the straight side to 1/r on the arc; this one
// eases in and out with a cubic Bézier on each side of a shorter arc (the
// profile Figma describes in "Desperately seeking squircles": with
// smoothing s the corner takes (1 + s) × r of each side, the arc keeps
// 90° × (1 − s) and each cubic covers the rest). The cubic's inner handle
// is placed so its curvature ends at exactly 1/r: the curvature then grows
// from 0 on the side to 1/r on the arc without any step.
//
// Everything is an SVG path piece, for a Shape's PathSvg: a corner is
// "L start C … A … C … end" and the caller strings them together.

// How far a corner of radius r reaches along each side
function reach(r, s) {
    return r > 0 ? (1 + s) * r : 0
}

function num(v) {
    return String(Math.round(v * 1000) / 1000)
}

// The corner at (cx, cy), reached travelling along (ix, iy) and left along
// (ox, oy) (unit vectors, a right angle). It starts reach(r, s) before the
// corner and ends reach(r, s) after it. r = 0: a plain square corner.
function corner(cx, cy, ix, iy, ox, oy, r, s) {
    // A point in the corner's own frame: `along` the way in (negative before
    // the corner), `across` towards the way out
    function at(along, across) {
        return num(cx + along * ix + across * ox) + " " + num(cy + along * iy + across * oy)
    }
    if (!(r > 0))
        return "L " + at(0, 0) + " "
    s = Math.max(0, Math.min(1, s))
    // Clockwise on screen (y down) when the way out is to the right of the way in
    const sweep = (ix * oy - iy * ox) > 0 ? 1 : 0
    // No smoothing: the plain quarter circle
    if (s < 0.001)
        return "L " + at(-r, 0) + " A " + num(r) + " " + num(r) + " 0 0 " + sweep + " " + at(0, r) + " "
    const p = (1 + s) * r
    const deg = Math.PI / 180
    const arc = 90 * (1 - s)                          // degrees left to the arc
    const chord = Math.sin(arc / 2 * deg) * r * Math.SQRT2
    const alpha = (90 - arc) / 2                      // degrees each cubic turns
    const t = r * Math.tan(alpha / 2 * deg)
    const beta = 45 * s
    const c = t * Math.cos(beta * deg)
    const d = c * Math.tan(beta * deg)
    // Inner handle: the cubic's end curvature (2/3)·b·sin(alpha)/(c² + d²)
    // equals the arc's 1/r; the outer handle takes what is left of p
    const b = 1.5 * (c * c + d * d) / (r * Math.sin(alpha * deg))
    const a = Math.max(0, p - chord - c - d - b)
    // In: along the first side, easing off it; the arc; out: the mirror
    // image (along ↔ across), easing onto the second side
    return "L " + at(-p, 0)
        + " C " + at(-p + a, 0) + " " + at(-p + a + b, 0) + " " + at(-p + a + b + c, d)
        + " A " + num(r) + " " + num(r) + " 0 0 " + sweep + " " + at(-d, p - a - b - c)
        + " C " + at(0, p - a - b) + " " + at(0, p - a) + " " + at(0, p) + " "
}
