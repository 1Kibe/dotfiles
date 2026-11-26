.pragma library
.import "palettes.js" as Palettes
.import "../settings/appearance.js" as Appearance

// A theme of the owner's own (Configurações → Temas → Novo tema
// personalizado): the editor's model, made from scratch (a fixed neutral
// template) or from a theme and flavor of the catalog, every color editable,
// and turned into a theme file the same validator checks (palettes.js
// validateTheme). Plain JS: read by the editor, state/ThemeCatalog and the
// tests. Kept out of the repo (~/.local/share/dotfiles/themes).

// "Do zero": neutral grays and seven plain colors
var TEMPLATE = {
    escuro: true,
    roles: { bgDeep: "#111111", bgHard: "#181818", bg: "#202020", bg1: "#2c2c2c", bg2: "#3a3a3a",
             fg: "#e6e6e6", fg2: "#cfcfcf", fg4: "#9a9a9a", text: "#e6e6e6", gray: "#808080" },
    named: { yellow: "#e5c07b", orange: "#d19a66", red: "#e06c75", green: "#98c379", aqua: "#56b6c2",
             blue: "#61afef", purple: "#c678dd" },
    ansi: ["#202020", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#cfcfcf"],
    accent: "blue",
    syntaxTheme: "base16"
}

// Its own themes' ids: "seu-" and six letters or digits (never one of the
// repo's, which never start so)
var OWN_ID = /^seu-[a-z0-9]{6}$/
// The name the owner gives it: the themes' name pattern, at most 24
var NAME_MAX = 24
// The least contrast of each text tone over the background (the editor's
// labels; the theme is saved anyway)
var MINIMUMS = { fg: 4.5, fg2: 4.5, text: 4.5, fg4: 3, gray: 2.2 }

function copy(o) {
    return JSON.parse(JSON.stringify(o))
}

// The model from scratch
function fromScratch() {
    return Object.assign(copy(TEMPLATE), { nome: "", licenca: "Próprio" })
}

// The model from a checked theme and one of its flavors: its colors as they
// are; the default accent is the named color it equals (or the nearest one)
function fromBase(theme, flavorId) {
    if (!theme || !theme.sabores)
        return fromScratch()
    const id = Object.prototype.hasOwnProperty.call(theme.sabores, flavorId) ? flavorId : Palettes.flavors(theme)[0].id
    const f = theme.sabores[id]
    return { nome: "", licenca: theme.licenca, escuro: f.escuro === true, roles: copy(f.papeis), named: copy(f.nomeadas),
             ansi: f.ansi.slice(), accent: nearestName(theme.destaquePadrao.accent, f.nomeadas),
             syntaxTheme: Palettes.syntaxTheme(f.syntaxTheme) }
}

function rgb(c) {
    return [1, 3, 5].map(i => parseInt(c.substr(i, 2), 16))
}
function nearestName(hex, named) {
    let best = "blue", dist = Infinity
    for (const n of Palettes.NAMED) {
        const a = rgb(hex), b = rgb(named[n])
        const d = (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2
        if (d < dist) {
            dist = d
            best = n
        }
    }
    return best
}

// Each text tone's contrast over the background: [{ role, ratio, least, ok }]
function contrasts(model) {
    return Object.keys(MINIMUMS).map(role => {
        const ratio = Palettes.contrast(model.roles[role], model.roles.bg)
        return { role: role, ratio: ratio, least: MINIMUMS[role], ok: ratio >= MINIMUMS[role] }
    })
}

// A ratio as the labels read it: one decimal, with a comma
function ratioText(r) {
    return (Math.floor(r * 10) / 10).toFixed(1).replace(".", ",")
}

// A new id: "seu-" and six of [a-z0-9]; `random` (0 to 1) for the tests
function newId(random, taken) {
    const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
    const r = random || Math.random
    for (let tries = 0; tries < 100; tries++) {
        let id = "seu-"
        for (let i = 0; i < 6; i++)
            id += letters[Math.floor(r() * letters.length) % letters.length]
        if (!taken || !taken.includes(id))
            return id
    }
    return ""
}

// The name, trimmed, if it may be one: { ok, nome }
function checkName(text) {
    const nome = typeof text === "string" ? text.trim() : ""
    return { ok: nome.length > 0 && nome.length <= NAME_MAX && Palettes.TEXT.test(nome), nome: nome }
}

// The model as a theme file's object, checked by the same validator:
// { ok, theme }. One flavor, in the dark or the light place by its type
function build(model, id) {
    const no = { ok: false, theme: null }
    const name = checkName(model.nome)
    if (!OWN_ID.test(id) || !name.ok || !Palettes.NAMED.includes(model.accent))
        return no
    const accent = String(model.named[model.accent]).toLowerCase()
    if (!Palettes.isHex(accent))
        return no
    const place = model.escuro === true ? "dark" : "light"
    const obj = {
        versao: 1, id: id, nome: name.nome,
        licenca: typeof model.licenca === "string" && Palettes.TEXT.test(model.licenca) ? model.licenca : "Próprio",
        destaquePadrao: { accent: accent, light: lightOf(accent) },
        sabores: {}
    }
    obj.sabores[place] = {
        rotulo: model.escuro === true ? "Escuro" : "Claro", escuro: model.escuro === true,
        syntaxTheme: Palettes.syntaxTheme(model.syntaxTheme),
        papeis: copy(model.roles), nomeadas: copy(model.named), ansi: model.ansi.slice()
    }
    return Palettes.validateTheme(obj)
}

// A default accent's light tone (the shell's accentPair: 45% toward white)
function lightOf(hex) {
    return Appearance.mix(hex, "#ffffff", 0.45)
}

// The theme file's text (what is written), two-space JSON
function serialize(theme) {
    return JSON.stringify(theme, null, 2) + "\n"
}
