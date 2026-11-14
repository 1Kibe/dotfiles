.pragma library

// Configurações → Atalhos: the list of `hypr-atalhos --json` (the keybinds
// Hyprland has in use, grouped, plus the touchpad gestures) checked before
// it reaches the screen. Plain JS: read by settings/cards/KeybindList and
// by the tests. Nothing here is ever written anywhere; the texts are shown
// as plain text only.

var MAX_BYTES = 256 * 1024
var MAX_ITEMS = 500
var MAX_TEXT = 200
var MAX_KEYS = 16
// Control characters (line breaks included), the ones that turn the
// direction of the text around, separators and invisible ones
var BAD = /[\u0000-\u001f\u007f-\u009f\u00ad\u034f\u0600-\u0605\u061c\u06dd\u070f\u115f\u1160\u17b4\u17b5\u180e\u200b-\u200f\u2028-\u202e\u2060-\u2064\u2066-\u206f\u2800\u3164\ufe00-\ufe0f\ufeff\uffa0\ufff9-\ufffc]|\udb40[\udc00-\udc7f\udd00-\uddef]|[\ud800-\udbff](?![\udc00-\udfff])|(?:^|[^\ud800-\udbff])[\udc00-\udfff]/

function text(v) {
    return typeof v === "string" && v.length > 0 && v.length <= MAX_TEXT && !BAD.test(v)
}

// An item: exactly { g, t, k }, each one checked; null when it does not pass
function item(x) {
    if (x === null || typeof x !== "object" || Array.isArray(x))
        return null
    const keys = Object.keys(x)
    if (keys.length !== 3 || !keys.includes("g") || !keys.includes("t") || !keys.includes("k"))
        return null
    if (!text(x.g) || !text(x.t) || !Array.isArray(x.k) || x.k.length < 1 || x.k.length > MAX_KEYS)
        return null
    if (!x.k.every(text))
        return null
    return { group: x.g, text: x.t, keys: x.k.slice() }
}

// The output → { ok, groups: [{ name, items: [{ group, text, keys }] }] }.
// Too big, not JSON, not a list or too long: ok false and nothing; a bad
// item is left out, the others stay
function parse(out) {
    const none = { ok: false, groups: [] }
    if (typeof out !== "string" || out.length === 0 || out.length > MAX_BYTES)
        return none
    let data = null
    try {
        data = JSON.parse(out)
    } catch (e) {
        return none
    }
    if (!Array.isArray(data) || data.length > MAX_ITEMS)
        return none
    const groups = []
    const at = {}
    for (const x of data) {
        const it = item(x)
        if (it === null)
            continue
        if (!Object.prototype.hasOwnProperty.call(at, it.group)) {
            at[it.group] = groups.length
            groups.push({ name: it.group, items: [] })
        }
        groups[at[it.group]].items.push(it)
    }
    return { ok: true, groups: groups }
}

// The search: every word somewhere in the text, the group or the keys,
// without case (indexOf, never a pattern)
function matches(it, query) {
    const words = String(query).toLowerCase().split(/\s+/).filter(w => w.length > 0)
    if (words.length === 0)
        return true
    const hay = [it.text, it.group].concat(it.keys).join(" ").toLowerCase()
    return words.every(w => hay.indexOf(w) >= 0)
}

// The groups with only the items that match (empty groups left out)
function filter(groups, query) {
    return groups.map(g => ({ name: g.name, items: g.items.filter(it => matches(it, query)) }))
                 .filter(g => g.items.length > 0)
}
