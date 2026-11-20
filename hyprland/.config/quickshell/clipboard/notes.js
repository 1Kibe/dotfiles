.pragma library
.import "../lock/text.js" as Clean

// The Anotações tab's list, from NotesStore's notes ({ nid, title, body,
// color, pinned, pinnedAt }). Plain JS: read by the shell and by the tests.

// The pinned first, in the order they were pinned (pinnedAt), then the
// others in the store's order (the order dragged by hand)
function ordered(list) {
    const all = Array.isArray(list) ? list.filter(n => n) : []
    const pinned = all.filter(n => n.pinned === true).sort((a, b) => (a.pinnedAt || 0) - (b.pinnedAt || 0))
    return pinned.concat(all.filter(n => n.pinned !== true))
}

// Lower case and no accents, so "Ação" matches "acao"
function fold(text) {
    return String(text || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}

// The notes whose title or text has the query (no case, no accents)
function filtered(list, query) {
    const q = fold(query).trim()
    const all = Array.isArray(list) ? list : []
    return q === "" ? all : all.filter(n => fold(n.title).includes(q) || fold(n.body).includes(q))
}

// The start of a note's text on the list: its first line with text,
// cleaned, at most 80 characters
function preview(text) {
    const line = String(text || "").split("\n").find(l => l.trim() !== "") || ""
    return Clean.clean(line, 80)
}

// The note shown after the list changed: the chosen one while it is still
// listed, else the first listed, else none ("")
function keepChosen(rows, nid) {
    if (rows.some(n => n.nid === nid))
        return nid
    return rows.length > 0 ? rows[0].nid : ""
}
