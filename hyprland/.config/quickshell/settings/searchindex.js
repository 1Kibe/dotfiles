.pragma library

// Search of the settings panel: every key of the schema by its label,
// description and synonyms, plus the page and card names, without accents
// and case. Several words narrow the result (every word must match some
// text of the entry). Plain JS: read by settings/Search and by the tests.

// "Ção" → "cao": no accents, lower case, single spaces
function fold(text) {
    return String(text).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/\s+/g, " ").trim()
}

// One entry per key: { key, page, card, label, text } (text is folded)
function build(schema) {
    const pages = {}
    for (const p of schema.PAGES)
        pages[p.id] = p
    const entries = []
    for (const key of Object.keys(schema.KEYS)) {
        const k = schema.KEYS[key]
        if (k.hidden === true)
            continue
        const page = pages[k.page]
        const card = (schema.CARDS[k.page] || []).find(c => c.id === k.card)
        const words = [k.label, k.desc || "", (k.syn || []).join(" "), page ? page.name : "", card ? card.title : ""]
        entries.push({ key: key, page: k.page, card: k.card, label: k.label, text: fold(words.join(" ")) })
    }
    // The pages themselves (Atalhos and Sobre have no keys)
    for (const p of schema.PAGES)
        entries.push({ key: "", page: p.id, card: "", label: p.name, text: fold(`${p.name} ${p.sub}`) })
    return entries
}

// The entries that match every word of the query, the label matches first,
// at most `limit`
function query(entries, text, limit) {
    const words = fold(text).split(" ").filter(w => w.length > 0)
    if (words.length === 0)
        return []
    const found = entries.filter(e => words.every(w => e.text.includes(w)))
    const score = e => words.filter(w => fold(e.label).includes(w)).length
    found.sort((a, b) => score(b) - score(a))
    return found.slice(0, limit || 8)
}
