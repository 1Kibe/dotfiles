.pragma library

// A profile (Configurações → Perfis, Super+T): a name, the values of the
// schema's keys marked `profile: true` and maybe a picture of its own (always
// "papel.png", re-encoded by the shell). Its folder is its id, drawn by the
// shell; the name is only shown. Plain JS: read by state/ProfileStore and the
// tests. Kept out of the repo (~/.local/share/dotfiles/profiles/<id>/).

// A profile's id (its folder): the themes' id pattern
var ID = /^[a-z0-9][a-z0-9-]{0,31}$/
// Its picture: one fixed name, or none
var PAPEL = "papel.png"
// At most this many profiles of the owner's (and this many bytes a file)
var MAX = 24
var MAX_BYTES = 65536

// The name: 1 to 32 letters (accented too), digits, spaces and . _ -; no
// space at either end, never "." or ".." alone nor the sequence "..", and at
// least one letter or digit. No markup characters, no control or direction
// characters (only these are allowed at all)
var NAME_CHARS = /^[A-Za-z0-9À-ÖØ-öø-ÿ._ -]{1,32}$/
function checkName(text) {
    if (typeof text !== "string")
        return false
    return NAME_CHARS.test(text) && text === text.trim() && !text.includes("..")
           && /[A-Za-z0-9À-ÖØ-öø-ÿ]/.test(text)
}

// The keys a profile keeps: the schema's marked `profile: true`, in its order
function profileKeys(schema) {
    return Object.keys(schema.KEYS).filter(k => schema.KEYS[k].profile === true)
}

function own(o, k) {
    return o !== null && typeof o === "object" && Object.prototype.hasOwnProperty.call(o, k)
}

// A profile file's text checked: { ok, profile: { nome, valores, papel } }.
// Only the schema's profile keys are read (iterating the schema, never the
// file), each through the schema's own validator (`validate(spec, value)`);
// theme and flavor must exist in the catalog (`themeOk(theme, flavor)`). A
// key missing or refused takes the repo's default (`defaults`). Anything
// else in the file is dropped: the profile is written back from this.
function validateProfile(text, schema, validate, defaults, themeOk) {
    const no = { ok: false, profile: null }
    if (typeof text !== "string" || text.length > MAX_BYTES)
        return no
    let obj = null
    try {
        obj = JSON.parse(text)
    } catch (e) {
        return no
    }
    if (obj === null || typeof obj !== "object" || Array.isArray(obj))
        return no
    if (!own(obj, "versao") || obj.versao !== 1 || !own(obj, "nome") || !checkName(obj.nome))
        return no
    if (!own(obj, "papel") || (obj.papel !== null && obj.papel !== PAPEL))
        return no
    const given = own(obj, "valores") && obj.valores !== null && typeof obj.valores === "object" && !Array.isArray(obj.valores)
                  ? obj.valores : {}
    const valores = {}
    for (const key of profileKeys(schema)) {
        let v = defaults[key]
        if (own(given, key)) {
            const r = validate(schema.KEYS[key], given[key])
            if (r.ok)
                v = r.value
        }
        valores[key] = v
    }
    if (!themeOk(valores.theme, valores.flavor)) {
        valores.theme = defaults.theme
        valores.flavor = defaults.flavor
    }
    return { ok: true, profile: { nome: obj.nome, valores: valores, papel: obj.papel } }
}

// The file's text: only the checked fields, in a fixed order
function serialize(profile) {
    return JSON.stringify({ versao: 1, nome: profile.nome, valores: profile.valores, papel: profile.papel }, null, 2) + "\n"
}

// A new id: "p-" and eight letters or digits, never one taken; `random` for
// the tests
function newId(random, taken) {
    const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
    const r = random || Math.random
    for (let tries = 0; tries < 100; tries++) {
        let id = "p-"
        for (let i = 0; i < 8; i++)
            id += letters[Math.floor(r() * letters.length) % letters.length]
        if (!taken || !taken.includes(id))
            return id
    }
    return ""
}

// Two value maps the same (the profile's against today's: "alterado")
function sameValues(a, b, keys) {
    return keys.every(k => JSON.stringify(a[k]) === JSON.stringify(b[k]))
}

// The groups of settings that differ between two value maps, as the page
// names them ("tema", "papel de parede"): the title of each key's card in
// the schema, in lower case, with two names of their own (the theme's card
// is the whole theme; the picture's card is the wallpaper). In the schema's
// order, each once
var GROUP_NAMES = { grade: "tema", imagem: "papel de parede", ajuste: "papel de parede" }
function changedGroups(schema, keys, a, b) {
    const out = []
    for (const k of keys) {
        if (JSON.stringify(a[k]) === JSON.stringify(b[k]))
            continue
        const spec = schema.KEYS[k]
        let name = spec && GROUP_NAMES[spec.card]
        if (!name) {
            const card = spec ? (schema.CARDS[spec.page] || []).find(c => c.id === spec.card) : null
            name = card ? card.title.toLowerCase() : k
        }
        if (!out.includes(name))
            out.push(name)
    }
    return out
}
// The list as the banner says it: up to three, then "e mais N"
function groupsText(groups) {
    if (groups.length <= 3)
        return groups.join(", ")
    return groups.slice(0, 3).join(", ") + ` e mais ${groups.length - 3}`
}
