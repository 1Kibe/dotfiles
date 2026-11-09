.pragma library

// Text from outside (player titles, the user's full name, the keyboard
// layout) shown on the lock and login screens: control and bidi characters
// (which could reorder or hide what is shown) become spaces, invisible
// characters go away, long runs of combining marks are cut to two, runs of
// spaces shrink to one, and it is cut to `max` characters. Shared with the
// login screen: pure JavaScript.
//   U+0000–U+001F, U+007F–U+009F  control                     → space
//   U+200E, U+200F               left-to-right / right-to-left marks
//   U+202A–U+202E                embeddings and overrides
//   U+2066–U+2069                isolates
//   U+200B–U+200D, U+2060, U+FEFF  zero-width characters     → removed
//   combining marks (U+0300–036F, 1AB0–1AFF, 1DC0–1DFF, 20D0–20FF,
//   FE20–FE2F): at most 2 in a row
function clean(value, max) {
    if (typeof value !== "string")
        return ""
    const limit = max > 0 ? max : 120
    return value
        .replace(/[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E\u2066-\u2069]/g, " ")
        .replace(/[\u200B-\u200D\u2060\uFEFF]/g, "")
        .replace(/([\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]{2})[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]+/g, "$1")
        .replace(/ {2,}/g, " ")
        .trim()
        .slice(0, limit)
}
