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

// Names the shell's own notices use (their skeleton): one from outside
// whose skeleton is one of them carries the "externo" tag, so it never
// passes for the shell's
var RESERVED = ["dispositivos", "atualizacoes", "sistema", "bateria", "quickshell", "hyprland"]
// Combining marks and variation selectors (also the supplement's, a pair)
var SKELETON_MARKS = /[\u0300-\u036F\u034F\u17B4\u17B5\u180B-\u180D\uFE00-\uFE0F\uFE20-\uFE2F]|\uDB40[\uDD00-\uDDEF]/g
// The common Cyrillic and Greek look-alikes of Latin letters
var CONFUSABLES = { "\u0430": "a", "\u0435": "e", "\u043E": "o", "\u0440": "p", "\u0441": "c", "\u0443": "y", "\u0445": "x", "\u0456": "i", "\u0458": "j", "\u0455": "s", "\u0501": "d", "\u04BB": "h", "\u04CF": "l", "\u043A": "k", "\u043C": "m", "\u0442": "t", "\u043D": "h", "\u0432": "b", "\u051B": "q", "\u051D": "w", "\u03B1": "a", "\u03BF": "o", "\u03C1": "p", "\u03BD": "v", "\u03B9": "i", "\u03BA": "k", "\u03C4": "t", "\u03C5": "u", "\u03B5": "e", "\u03C7": "x", "\u03B2": "b", "\u03B7": "n" }
var CONFUSABLE_CHARS = /[\u0430\u0435\u043E\u0440\u0441\u0443\u0445\u0456\u0458\u0455\u0501\u04BB\u04CF\u043A\u043C\u0442\u043D\u0432\u051B\u051D\u03B1\u03BF\u03C1\u03BD\u03B9\u03BA\u03C4\u03C5\u03B5\u03C7\u03B2\u03B7]/g
// Compatibility forms split, lower case, marks and selectors gone,
// look-alikes as Latin, then only a to z: what a name looks like
function skeleton(text) {
    if (typeof text !== "string")
        return ""
    return text.normalize("NFKD").toLowerCase().replace(SKELETON_MARKS, "")
               .replace(CONFUSABLE_CHARS, c => CONFUSABLES[c]).replace(/[^a-z]/g, "")
}
function isReserved(appName) {
    return RESERVED.includes(skeleton(appName))
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
