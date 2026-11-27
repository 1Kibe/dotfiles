.pragma library
.import "../settings/appearance.js" as Appearance

// The themes (themes/<id>.json) checked and turned into the Theme's colors.
// Plain JS: read by state/ThemeCatalog, the generators and the tests. A
// theme is data only: every color "#rrggbb", every id and label by a fixed
// pattern; a key nobody knows is dropped and never reaches the result.

// A theme's id (also its file name)
var THEME_NAME = /^[a-z0-9][a-z0-9-]{0,31}$/
// The four fixed flavors (each theme fills the ones its palette has)
var FLAVORS = ["dark", "darkHard", "darkSoft", "light", "lightHard", "lightSoft"]
// A place is dark or light by its name: the file's escuro must say the same
// (GTK and the icons follow it)
function darkPlace(id) {
    return id.startsWith("dark")
}
// A flavor's label: the palette's own name for it, short plain text
// (Latin letters with accents; never × or ÷)
var LABEL = /^[A-Za-z0-9À-ÖØ-öø-ÿ][A-Za-z0-9À-ÖØ-öø-ÿ '()-]{0,23}$/
// The Theme's roles and named colors
var ROLES = ["bgDeep", "bgHard", "bg", "bg1", "bg2", "fg", "fg2", "fg4", "text", "gray"]
var NAMED = ["yellow", "orange", "red", "green", "aqua", "blue", "purple"]
// A theme's name and license: short plain text
var TEXT = /^[A-Za-z0-9À-ÖØ-öø-ÿ][A-Za-z0-9À-ÖØ-öø-ÿ .'()+-]{0,39}$/
// delta's syntax theme: a name of this fixed list only (delta --list-syntax-themes);
// anything else is base16, which follows the terminal's colors
var SYNTAX_THEMES = ["1337", "Catppuccin Frappe", "Catppuccin Latte", "Catppuccin Macchiato", "Catppuccin Mocha",
                     "Coldark-Cold", "Coldark-Dark", "DarkNeon", "Dracula", "GitHub", "Monokai Extended",
                     "Monokai Extended Bright", "Monokai Extended Light", "Monokai Extended Origin", "Nord",
                     "OneHalfDark", "OneHalfLight", "Solarized (dark)", "Solarized (light)", "Sublime Snazzy",
                     "TwoDark", "Visual Studio Dark+", "ansi", "base16", "base16-256", "gruvbox-dark",
                     "gruvbox-light", "zenburn"]

function isHex(c) {
    return typeof c === "string" && /^#[0-9a-fA-F]{6}$/.test(c)
}
function own(o, k) {
    return o !== null && typeof o === "object" && Object.prototype.hasOwnProperty.call(o, k)
}
// The syntax theme of a flavor: a name of the list, or base16
function syntaxTheme(name) {
    return typeof name === "string" && SYNTAX_THEMES.includes(name) ? name : "base16"
}

// A set of named colors, all present and "#rrggbb" (lower case), or null
function colors(o, names) {
    if (o === null || typeof o !== "object" || Array.isArray(o))
        return null
    const out = {}
    for (const k of names) {
        if (!own(o, k) || !isHex(o[k]))
            return null
        out[k] = o[k].toLowerCase()
    }
    return out
}
function flavor(f) {
    if (f === null || typeof f !== "object" || Array.isArray(f))
        return null
    if (!own(f, "rotulo") || typeof f.rotulo !== "string" || !LABEL.test(f.rotulo))
        return null
    if (!own(f, "escuro") || typeof f.escuro !== "boolean")
        return null
    const roles = colors(f.papeis, ROLES)
    const named = colors(f.nomeadas, NAMED)
    if (roles === null || named === null || !own(f, "ansi") || !Array.isArray(f.ansi) || f.ansi.length !== 8
            || !f.ansi.every(isHex))
        return null
    return { rotulo: f.rotulo, escuro: f.escuro, syntaxTheme: syntaxTheme(f.syntaxTheme), papeis: roles, nomeadas: named,
             ansi: f.ansi.map(c => c.toLowerCase()) }
}

// The file's object checked: { ok, theme }. Only the known keys come out
function validateTheme(obj) {
    const no = { ok: false, theme: null }
    if (obj === null || typeof obj !== "object" || Array.isArray(obj))
        return no
    if (!own(obj, "versao") || obj.versao !== 1)
        return no
    if (!own(obj, "id") || typeof obj.id !== "string" || !THEME_NAME.test(obj.id))
        return no
    if (!own(obj, "nome") || typeof obj.nome !== "string" || !TEXT.test(obj.nome))
        return no
    if (!own(obj, "licenca") || typeof obj.licenca !== "string" || !TEXT.test(obj.licenca))
        return no
    const accent = obj.destaquePadrao
    if (!own(obj, "destaquePadrao") || !own(accent, "accent") || !own(accent, "light") || !isHex(accent.accent)
            || !isHex(accent.light))
        return no
    if (!own(obj, "sabores") || obj.sabores === null || typeof obj.sabores !== "object" || Array.isArray(obj.sabores))
        return no
    const sabores = {}
    for (const id of FLAVORS) {
        if (!own(obj.sabores, id))
            continue
        const f = flavor(obj.sabores[id])
        if (f === null || f.escuro !== darkPlace(id))
            return no
        sabores[id] = f
    }
    if (Object.keys(sabores).length === 0)
        return no
    return { ok: true, theme: { versao: 1, id: obj.id, nome: obj.nome, licenca: obj.licenca,
                                destaquePadrao: { accent: accent.accent.toLowerCase(), light: accent.light.toLowerCase() },
                                sabores: sabores } }
}

// The flavors a theme has, in the fixed order: [{ id, rotulo }]
function flavors(theme) {
    if (!theme || !theme.sabores)
        return []
    return FLAVORS.filter(id => own(theme.sabores, id)).map(id => ({ id: id, rotulo: theme.sabores[id].rotulo }))
}

// A checked theme, a flavor and an accent id turned into the Theme's
// values (all "#rrggbb"). An unknown flavor: the theme's first one.
// "padrao": the theme's own pair; a named color: that color and its light
// tone (appearance.js accentPair, the same as before themes)
function resolve(theme, flavorId, accentId) {
    if (!theme || !theme.sabores)
        return null
    const id = own(theme.sabores, flavorId) ? flavorId : FLAVORS.find(f => own(theme.sabores, f))
    const f = theme.sabores[id]
    const pair = accentId === "padrao" || !NAMED.includes(accentId)
                 ? { accent: theme.destaquePadrao.accent, light: theme.destaquePadrao.light }
                 : Appearance.accentPair(accentId, f.nomeadas)
    return { flavor: id, roles: Object.assign({}, f.papeis), named: Object.assign({}, f.nomeadas), ansi: f.ansi.slice(),
             accent: pair.accent, accentLight: pair.light, escuro: f.escuro, syntaxTheme: f.syntaxTheme }
}

// WCAG contrast ratio of two "#rrggbb"
function luminance(c) {
    const v = [1, 3, 5].map(i => parseInt(c.substr(i, 2), 16) / 255)
                       .map(x => x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4))
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
}
function contrast(a, b) {
    const la = luminance(a)
    const lb = luminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}
