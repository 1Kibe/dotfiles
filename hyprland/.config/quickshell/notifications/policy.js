.pragma library

// Where a notification goes (state/NotificationState asks, the screen never
// decides): plain JS, read by the shell and by the tests. Nothing here
// looks at what a notification says: no notification is dropped for its
// subject (a player's included); only the caps, the pace and an empty text
// drop one.
//
// decide(n, ctx) → "drop" | "central" | "screen"
//   n = { urgent: bool, empty: bool }   (empty: no title nor body left
//                                        after the cleaning)
//   ctx = { overLimit: "" | "rate" | "cap", dnd, locked, fullscreen }
// In this order:
//   over a cap or the pace, or empty      → drop (never tracked, counted)
//   locked or asked to lock               → central
//   Não perturbe                          → central (an urgent one too,
//                                            unless URGENT_PIERCES_DND)
//   full screen and not urgent            → central
//   else                                  → screen (and the central)

// An urgent notification and Não perturbe: it stays in the central
var URGENT_PIERCES_DND = false
// Over a full-screen window: at most this many urgent cards a monitor, each
// for this long, then the central
var URGENT_FULLSCREEN_MAX = 2
var URGENT_FULLSCREEN_MS = 15000
// No urgent card stays longer than this (it then waits in the central)
var URGENT_MAX_MS = 60000

function dropReason(n, ctx) {
    if (ctx && (ctx.overLimit === "rate" || ctx.overLimit === "cap"))
        return ctx.overLimit
    if (!n || n.empty === true)
        return "text"
    return ""
}

function decide(n, ctx) {
    const c = ctx || {}
    if (dropReason(n, c) !== "")
        return "drop"
    if (c.locked === true)
        return "central"
    // The clock's panel open (it is in the list, in front of the user) or a
    // recording going on (a card would be filmed)
    if (c.listOpen === true)
        return "central"
    if (c.dnd === true && !(n.urgent === true && URGENT_PIERCES_DND))
        return "central"
    if (c.fullscreen === true && n.urgent !== true)
        return "central"
    return "screen"
}

// How long a card stays (ms): a normal one holdMs; an urgent one until it is
// closed, at most URGENT_MAX_MS, URGENT_FULLSCREEN_MS over a full screen
function cardTime(urgent, fullscreen, holdMs) {
    if (!urgent)
        return holdMs
    return fullscreen ? URGENT_FULLSCREEN_MS : URGENT_MAX_MS
}
