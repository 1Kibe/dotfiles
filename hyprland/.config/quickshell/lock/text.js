.pragma library

// Text from outside (player titles, the user's full name, the keyboard
// layout, network and device names) as shown: control and bidi characters
// (which could reorder or hide what is shown) become spaces, invisible
// characters go away, long runs of combining marks are cut to two, runs of
// spaces shrink to one, and it is cut to `max` characters. Shared with the
// login screen, which copies only this file: pure JavaScript, no imports.
//   U+0000–U+001F, U+007F–U+009F  control                     → space
//   U+061C, U+200E, U+200F       Arabic, left-to-right, right-to-left marks
//   U+2028, U+2029               line and paragraph separators
//   U+202A–U+202E                embeddings and overrides
//   U+2066–U+2069                isolates
//   U+00AD, U+180E               soft hyphen, Mongolian vowel separator → removed
//   U+115F, U+1160, U+2800, U+3164, U+FFA0  Hangul fillers and the blank
//                                Braille pattern (a name of only these
//                                would look blank)
//   U+200B–U+200D, U+2060–U+2064, U+FEFF  zero-width and invisible operators
//   U+FFF9–U+FFFB                interlinear annotation marks
//   U+E0000–U+E007F              tag characters
//   combining marks (U+0300–036F, 1AB0–1AFF, 1DC0–1DFF, 20D0–20FF,
//   FE20–FE2F): at most 2 in a row
function clean(value, max) {
    if (typeof value !== "string")
        return ""
    const limit = max > 0 ? max : 120
    return value
        .replace(/[\u0000-\u001F\u007F-\u009F\u061C\u200E\u200F\u2028\u2029\u202A-\u202E\u2066-\u2069]/g, " ")
        .replace(/[\u00AD\u115F\u1160\u180E\u200B-\u200D\u2060-\u2064\u2800\u3164\uFEFF\uFFA0\uFFF9-\uFFFB]|\uDB40[\uDC00-\uDC7F]/g, "")
        .replace(/([\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]{2})[\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]+/g, "$1")
        .replace(/ {2,}/g, " ")
        .trim()
        .slice(0, limit)
}

// Text that the settings refuse outright (a shortcut's description, an
// app's name, the system's name on the Sobre page): every control,
// direction, invisible or filler character, variation selectors, tags and
// lone surrogates. Kept here, the one copy: settings/keybinds.js, apps.js
// and about.js import it.
var BAD = /[\u0000-\u001f\u007f-\u009f\u00ad\u034f\u0600-\u0605\u061c\u06dd\u070f\u115f\u1160\u17b4\u17b5\u180e\u200b-\u200f\u2028-\u202e\u2060-\u2064\u2066-\u206f\u2800\u3164\ufe00-\ufe0f\ufeff\uffa0\ufff9-\ufffc]|\udb40[\udc00-\udc7f\udd00-\uddef]|[\ud800-\udbff](?![\udc00-\udfff])|(?:^|[^\ud800-\udbff])[\udc00-\udfff]/
