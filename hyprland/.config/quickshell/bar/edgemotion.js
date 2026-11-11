.pragma library

// The timeline of a panel that touches the screen's left or right edge
// (bar/EdgeTimeline), the bar's part first and the panel's after it: `u` is the
// fraction of the time, 0 to 1, at a constant pace (backwards when closing);
// the bar's part and the panel's part read it each with their own window and
// curve. Plain JS: read by the shell and by the tests.

// A CSS-like cubic bezier, curve = [x1, y1, x2, y2, ...] (QML's
// easing.bezierCurve): its value at time t, 0 to 1
function bezier(curve, t) {
    if (t <= 0)
        return 0
    if (t >= 1)
        return 1
    const x1 = curve[0], y1 = curve[1], x2 = curve[2], y2 = curve[3]
    const at = (a, b, s) => 3 * a * s * (1 - s) * (1 - s) + 3 * b * s * s * (1 - s) + s * s * s
    // The curve's own parameter for x = t, by bisection (x grows with it)
    let lo = 0, hi = 1, s = t
    for (let i = 0; i < 40; i++) {
        s = (lo + hi) / 2
        if (at(x1, x2, s) < t)
            lo = s
        else
            hi = s
    }
    return at(y1, y2, s)
}

function clamp01(x) {
    return Math.max(0, Math.min(1, x))
}

// The bar: 0 = its own end, round corner; 1 = at the screen's edge, square
// corner. Over the first `share` of the time
function barStep(u, curve, share) {
    return bezier(curve, clamp01(u / share))
}

// The panel: 0 = closed, 1 = open. From `from` to the end
function panelStep(u, curve, from) {
    return bezier(curve, clamp01((u - from) / (1 - from)))
}

// What the frame does on one side (Bar.qml): of the panels showing, those
// that touch that edge (edgeSide), the most open request (edgeStep), and
// whether any asks at all
function sideStep(panels, side) {
    let step = 0
    for (const p of panels)
        if (p && p.edgeSide === side)
            step = Math.max(step, Number(p.edgeStep) || 0)
    return step
}
function sideAsked(panels, side) {
    return panels.some(p => p && p.edgeSide === side)
}
