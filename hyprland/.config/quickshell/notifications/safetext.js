.pragma library

// Text from a notification (any program of the session, and through the
// browser any web page) as it may be shown: plain JS, read by the shell
// and by the tests. The input is cut first, before any pattern runs, so a
// huge string costs no more than a short one; nothing ever splits a
// surrogate pair. Then, as lock/text.js: control and direction characters
// become spaces (a line break in the body separates lines), invisible ones
// go, runs of combining marks are cut to two, runs of spaces to one; and
// it is cut to whole characters with "…".

var LIMITS = { app: 40, summary: 120, body: 400, action: 24, entry: 80 }
// Lines of a body: on a card and in the list
var CARD_LINES = 3
var LIST_LINES = 6
// The most of a body read at all (four times its limit, at most this)
var BODY_READ = 2000

var SPACE = /[\u0000-\u001F\u007F-\u009F\u061C\u200E\u200F\u2028\u2029\u202A-\u202E\u2066-\u2069]/g
var GONE = /[\u00AD\u115F\u1160\u180E\u200B-\u200D\u2060-\u2064\u2800\u3164\uFEFF\uFFA0\uFFF9-\uFFFB]|\uDB40[\uDC00-\uDC7F]/g
var MARKS = /([\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]{2})[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]+/g

// The first n code units, one less if that would split a pair
function head(s, n) {
    if (s.length <= n)
        return s
    const c = s.charCodeAt(n - 1)
    return s.slice(0, c >= 0xD800 && c <= 0xDBFF ? n - 1 : n)
}

// Cut to max whole characters, the last one "…" when cut
function cut(s, max) {
    let i = 0
    let count = 0
    let keep = 0
    while (i < s.length) {
        if (count === max - 1)
            keep = i
        const c = s.charCodeAt(i)
        i += c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length ? 2 : 1
        count++
        if (count > max)
            return s.slice(0, keep).replace(/\s+$/, "") + "…"
    }
    return s
}

// A lone half of a pair (left by whoever sent it) goes
function noLone(s) {
    let out = ""
    for (let i = 0; i < s.length; i++) {
        const c = s.charCodeAt(i)
        if (c >= 0xD800 && c <= 0xDBFF) {
            const d = i + 1 < s.length ? s.charCodeAt(i + 1) : 0
            if (d >= 0xDC00 && d <= 0xDFFF) {
                out += s[i] + s[i + 1]
                i++
            }
            continue
        }
        if (c < 0xDC00 || c > 0xDFFF)
            out += s[i]
    }
    return out
}

function tidy(s) {
    return noLone(s).replace(SPACE, " ").replace(GONE, "").replace(MARKS, "$1").replace(/ {2,}/g, " ").trim()
}

// One line: the app's name, a title, a button's text, a desktop entry
function clean(value, max) {
    if (typeof value !== "string")
        return ""
    const limit = max > 0 ? max : LIMITS.summary
    return cut(tidy(head(value, 4 * limit)), limit)
}

// A body: its own line breaks separate lines (at most maxLines kept, empty
// ones dropped), each line cleaned; then the whole cut to max
function cleanBody(value, max, maxLines) {
    if (typeof value !== "string")
        return ""
    const limit = max > 0 ? max : LIMITS.body
    const lines = head(value, Math.min(4 * limit, BODY_READ)).split(/\r\n|\r|\n/)
    const out = []
    for (const l of lines) {
        const t = tidy(l)
        if (t !== "")
            out.push(t)
        if (out.length === (maxLines > 0 ? maxLines : LIST_LINES))
            break
    }
    return cut(out.join("\n"), limit)
}
