.pragma library

// Text from outside (player titles, the user's full name, the keyboard
// layout) shown on the lock and login screens: control and bidi characters
// (which could reorder or hide what is shown) become spaces, runs of spaces
// shrink to one, and it is cut to `max` characters. Shared with the login
// screen: pure JavaScript.
//   U+0000–U+001F, U+007F–U+009F  control
//   U+200E, U+200F               left-to-right / right-to-left marks
//   U+202A–U+202E                embeddings and overrides
//   U+2066–U+2069                isolates
function clean(value, max) {
    if (typeof value !== "string")
        return ""
    const limit = max > 0 ? max : 120
    return value
        .replace(/[\u0000-\u001F\u007F-\u009F‎‏‪-‮⁦-⁩]/g, " ")
        .replace(/ {2,}/g, " ")
        .trim()
        .slice(0, limit)
}
