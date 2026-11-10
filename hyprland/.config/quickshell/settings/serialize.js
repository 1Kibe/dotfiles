.pragma library

// Values for the generated Lua (~/.config/hypr/settings.lua) and hyprlang
// (hypridle) files. Only finite numbers, booleans and texts get through;
// anything else throws, so a generator never writes a value it cannot
// quote. Names that end up there (monitors, apps) are checked by regex
// before.

function number(v) {
    if (!isFinite(v))
        throw new Error("serialize: número inválido")
    // Integers as integers; decimals with up to 6 places, no exponent
    return Number.isInteger(v) ? String(v) : String(Number(v.toFixed(6)))
}

// A Lua text between double quotes: the backslash and the quote escaped,
// every control character and the square brackets as decimal escapes, so
// nothing inside can end the string, start a comment or a long bracket
function luaString(s) {
    let out = ""
    for (const ch of s) {
        const c = ch.codePointAt(0)
        if (ch === "\\")
            out += "\\\\"
        else if (ch === "\"")
            out += "\\\""
        else if (ch === "\n")
            out += "\\n"
        else if (ch === "\r")
            out += "\\r"
        else if (ch === "\t")
            out += "\\t"
        else if (c < 0x20 || c === 0x7f || ch === "[" || ch === "]")
            out += "\\" + String(c).padStart(3, "0")
        else
            out += ch
    }
    return "\"" + out + "\""
}

function luaValue(v) {
    switch (typeof v) {
    case "number":
        return number(v)
    case "boolean":
        return v ? "true" : "false"
    case "string":
        return luaString(v)
    default:
        throw new Error("serialize: tipo não aceito no Lua")
    }
}

// hyprlang takes the rest of the line as the value: no line breaks or any
// other control character, no "#" (a comment) and no "$" (a variable);
// texts with them are refused, never written
function confValue(v) {
    switch (typeof v) {
    case "number":
        return number(v)
    case "boolean":
        return v ? "true" : "false"
    case "string":
        if (/[\u0000-\u001f\u007f#$]/.test(v) || v !== v.trim())
            throw new Error("serialize: texto não aceito no hyprlang")
        return v
    default:
        throw new Error("serialize: tipo não aceito no hyprlang")
    }
}

// Names that go into the generated files
function monitorName(name) {
    if (typeof name !== "string" || !/^[A-Za-z0-9._-]{1,32}$/.test(name))
        throw new Error("serialize: nome de monitor inválido")
    return name
}

function desktopId(id) {
    if (typeof id !== "string" || !/^[A-Za-z0-9._-]{1,96}\.desktop$/.test(id))
        throw new Error("serialize: app inválido")
    return id
}
