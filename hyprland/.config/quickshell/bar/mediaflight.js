.pragma library

// The way the center island's cover and equalizer go into the music panel
// while it opens (bar/MediaPanel, T1b), as pure functions of the progress
// (0 = closed, 1 = open), so the path can be checked without a screen.
// Closing runs the same path backwards.
//
// Two phases, so neither ever leaves the island + panel shape nor passes over
// the bar:
// 1. 0–35%: small, straight down from the island to just under the bar's
//    edge, keeping the island's x.
// 2. 35–100%: to the fixed place in the open panel, growing.
// The island itself only narrows during phase 2, once both have left it.

var split = 0.35

function clamp01(v) {
    return Math.max(0, Math.min(1, v))
}

// 0 during phase 1, then 0 → 1
function phase2(p) {
    return clamp01((p - split) / (1 - split))
}

// How much the island has narrowed (its cover and equalizer slots)
function islandShrink(p) {
    return phase2(p)
}

// The rectangle (x, y, w, h, r) at progress p, from src (in the island) to
// dst (in the open panel); `below` is the y just under the bar's edge where
// phase 1 ends. The size changes in phase 2 only.
function rectAt(p, src, dst, below) {
    if (p <= split) {
        var t = clamp01(p / split)
        return { x: src.x, y: src.y + (below - src.y) * t, w: src.w, h: src.h, r: src.r }
    }
    var u = phase2(p)
    return {
        x: src.x + (dst.x - src.x) * u,
        y: below + (dst.y - below) * u,
        w: src.w + (dst.w - src.w) * u,
        h: src.h + (dst.h - src.h) * u,
        r: src.r + (dst.r - src.r) * u
    }
}
