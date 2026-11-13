.pragma library

// Checks one value against its key of settings/schema.js. Anything that
// does not fit gives { ok: false, value: spec.def }: the caller keeps the
// default and never logs the value itself.

// No control character (C0, DEL) anywhere in a text
var CONTROL = /[\u0000-\u001f\u007f]/

function bad(spec) {
    return { ok: false, value: spec.def }
}

function good(value) {
    return { ok: true, value: value }
}

// On the step from min (a step of 0.05 from 0.5: 0.55, 0.6...), within a
// small tolerance for decimals
function onStep(spec, v) {
    if (!spec.step)
        return true
    const n = (v - (spec.min || 0)) / spec.step
    return Math.abs(n - Math.round(n)) < 1e-6
}

function number(spec, v, integer) {
    if (typeof v !== "number" || !isFinite(v))
        return bad(spec)
    if (integer && !Number.isInteger(v))
        return bad(spec)
    if ((spec.min !== undefined && v < spec.min) || (spec.max !== undefined && v > spec.max) || !onStep(spec, v))
        return bad(spec)
    return good(v)
}

// "~" or "~/..." becomes the home; the result must be absolute, with no ".."
// part and no control character. Outside the home is fine (an external
// disk). Returns "" when it does not pass.
function expandPath(text, home) {
    if (typeof text !== "string" || text === "" || text.length > 4096 || CONTROL.test(text))
        return ""
    let p = text
    if (p === "~")
        p = home
    else if (p.startsWith("~/"))
        p = home + p.slice(1)
    if (!p.startsWith("/"))
        return ""
    if (p.split("/").some(part => part === ".."))
        return ""
    return p
}

// home is only needed for "path"
function validate(spec, value, home) {
    if (!spec)
        return { ok: false, value: undefined }
    switch (spec.type) {
    case "bool":
        return typeof value === "boolean" ? good(value) : bad(spec)
    case "int":
        return number(spec, value, true)
    case "real":
        return number(spec, value, false)
    case "enum":
        return spec.options.some(o => o.value === value) ? good(value) : bad(spec)
    case "string":
        if (typeof value !== "string" || value.length > 256 || CONTROL.test(value))
            return bad(spec)
        if (spec.pattern && !spec.pattern.test(value))
            return bad(spec)
        return good(value)
    case "color":
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? good(value.toLowerCase()) : bad(spec)
    case "path":
        // Kept as written ("~/..." stays portable); checked expanded
        return expandPath(value, home || "/nonexistent-home") !== "" ? good(value) : bad(spec)
    case "list":
        if (!Array.isArray(value) || value.length > spec.options.length)
            return bad(spec)
        const ids = spec.options.map(o => o.value)
        const seen = {}
        for (const v of value) {
            if (!ids.includes(v) || seen[v])
                return bad(spec)
            seen[v] = true
        }
        return good(value.slice())
    case "idlist":
        // Free names (app ids): each one the key's pattern, no repeats, at
        // most spec.max of them
        if (!Array.isArray(value) || value.length > (spec.max || 0))
            return bad(spec)
        const names = {}
        for (const v of value) {
            if (typeof v !== "string" || v.length > 256 || CONTROL.test(v) || !spec.pattern || !spec.pattern.test(v)
                    || names[v])
                return bad(spec)
            names[v] = true
        }
        return good(value.slice())
    default:
        return bad(spec)
    }
}
