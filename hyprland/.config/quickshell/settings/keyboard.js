.pragma library

// Configurações → Teclado e mouse → Layout, the parts with no state: the
// system's keyboard read from `LC_ALL=C localectl status`, the argument list
// that changes it, the Lua line of the preview and the names shown for the
// codes. Plain JS: read by state/KeyboardLayout and by the tests. Every value
// that leaves here passes a fixed pattern first; anything else is "" (the
// layout: unknown; the model and the options: left out).

var LAYOUT = /^[a-z]{2,8}$/
var MODEL = /^[a-z0-9][a-z0-9_]{0,23}$/
var VARIANT = /^[a-z0-9][a-z0-9_-]{0,31}$/
var OPTIONS = /^[A-Za-z0-9_:,()-]{1,200}$/

// One "Name: value" line of the status ("" when missing)
function field(text, name) {
    for (const line of String(text).split("\n")) {
        const m = /^\s*([A-Za-z0-9 ]+):\s*(.*)$/.exec(line)
        if (m && m[1] === name)
            return m[2].trim()
    }
    return ""
}

// { layout, model, variant, options }: each one checked, "" when it does not
// pass (two layouts "br,us" read as unknown)
function parseStatus(text) {
    const pick = (name, pattern) => {
        const v = field(text, name)
        return pattern.test(v) ? v : ""
    }
    return {
        layout: pick("X11 Layout", LAYOUT),
        model: pick("X11 Model", MODEL),
        variant: pick("X11 Variant", VARIANT),
        options: pick("X11 Options", OPTIONS)
    }
}

// The command that sets the system's (the login's) layout: the chosen one,
// the system's own model and options, the plain variant. null when the
// layout does not pass or is not in `list`
function setArgs(layout, status, list) {
    if (typeof layout !== "string" || !LAYOUT.test(layout) || !Array.isArray(list) || !list.includes(layout))
        return null
    const model = status && MODEL.test(status.model) ? status.model : ""
    const options = status && OPTIONS.test(status.options) ? status.options : ""
    return ["localectl", "--no-pager", "set-x11-keymap", "--no-convert", layout, model, "", options]
}

// The preview: Hyprland only, nothing saved. `lua`: serialize.js luaValue
function previewCode(layout, lua) {
    if (typeof layout !== "string" || !LAYOUT.test(layout))
        throw new Error("keyboard: layout inválido")
    return `hl.config({ input = { kb_layout = ${lua(layout)}, kb_variant = ${lua("")} } })`
}

// Names for the common codes; the others show the code alone
var NAMES = {
    br: "Português (Brasil)", us: "Inglês (EUA)", pt: "Português (Portugal)", es: "Espanhol",
    latam: "Espanhol (América Latina)", gb: "Inglês (Reino Unido)", de: "Alemão", fr: "Francês", it: "Italiano"
}
function label(code) {
    return Object.prototype.hasOwnProperty.call(NAMES, code) ? `${NAMES[code]} · ${code}` : code
}
// The list for the page's choice: the named ones first, then the rest
function options(list) {
    const named = Object.keys(NAMES).filter(c => list.includes(c))
    const rest = list.filter(c => !named.includes(c))
    return named.concat(rest).map(c => ({ value: c, label: label(c) }))
}

// local.lua (text only) sets a layout outside comments: it loads last and wins
function localSetsLayout(text) {
    return String(text).split("\n").some(l => !/^\s*--/.test(l) && /\bkb_layout\s*=/.test(l.replace(/--.*$/, "")))
}
