.pragma library

// The bar's items from the settings (Configurações → Barra) and the clock's
// text. Plain JS: read by bar/Bar.qml, bar/Clock.qml and by the tests.

// Every item the bar knows ("clock" is the center island: the clock, and the
// music island around it)
var IDS = ["workspaces", "system", "clock", "recording", "volume", "network", "bluetooth", "battery", "power"]

// The three areas: each item at most once (the first area that has it wins,
// left, center, right), the hidden and the unknown ones out. A separator
// ("|") goes after the workspaces and before the power button when
// something is beside them in the same area, as the bar has always had.
function areas(left, center, right, hidden) {
    const seen = {}
    const hid = Array.isArray(hidden) ? hidden : []
    function take(list) {
        const out = []
        for (const id of Array.isArray(list) ? list : []) {
            if (typeof id !== "string" || !IDS.includes(id) || seen[id])
                continue
            seen[id] = true
            if (!hid.includes(id))
                out.push(id)
        }
        return withSeparators(out)
    }
    return { left: take(left), center: take(center), right: take(right) }
}

function withSeparators(ids) {
    const out = []
    ids.forEach((id, i) => {
        if (id === "power" && i > 0 && out[out.length - 1] !== "|")
            out.push("|")
        out.push(id)
        if (id === "workspaces" && i < ids.length - 1)
            out.push("|")
    })
    return out
}

// The clock: "HH:mm" (24 h) or "h:mm AP", with ":ss" when asked
function timePattern(h24, seconds) {
    return (h24 ? "HH:mm" : "h:mm") + (seconds ? ":ss" : "") + (h24 ? "" : " AP")
}

// The date as the bar writes it: lower case, no abbreviation dots
// ("qua. 11/11" → "qua 11/11"); `formatted` is the date already formatted
// with the chosen pattern
function dateText(formatted) {
    return String(formatted).replace(/\./g, "").toLowerCase()
}

// The whole text: the date (if any) and the time, two spaces apart
function clockText(dateTxt, timeTxt) {
    return dateTxt === "" ? timeTxt : `${dateTxt}  ${timeTxt}`
}

// The settings card (settings/cards/BarItems): `lists` = { barLeft,
// barCenter, barRight } (arrays of ids); `id` goes to `area` (one of those
// keys) at `index` (in that area's list without it), taken out of wherever
// it was. Returns new arrays, the input untouched.
function moveItem(lists, id, area, index) {
    const out = {}
    for (const key of ["barLeft", "barCenter", "barRight"])
        out[key] = (Array.isArray(lists[key]) ? lists[key] : []).filter(x => x !== id)
    if (!Object.prototype.hasOwnProperty.call(out, area) || !IDS.includes(id))
        return lists
    const at = Math.max(0, Math.min(out[area].length, index))
    out[area].splice(at, 0, id)
    return out
}

// The eye: an id in or out of the hidden list
function toggleHidden(hidden, id) {
    const list = Array.isArray(hidden) ? hidden.slice() : []
    const i = list.indexOf(id)
    if (i >= 0)
        list.splice(i, 1)
    else if (IDS.includes(id))
        list.push(id)
    return list
}
