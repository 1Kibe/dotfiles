.pragma library

// Values for the generated Lua (~/.config/hypr/dotfiles_settings.lua) and hyprlang
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
// other control character, no "#" (a comment), no "$" (a variable) and no
// "{{" (an expression); texts with them are refused, never written. This
// keeps only the hyprlang syntax safe: a text that hypridle runs as a
// command (on-timeout = ...) goes through shellQuote() first.
function confValue(v) {
    switch (typeof v) {
    case "number":
        return number(v)
    case "boolean":
        return v ? "true" : "false"
    case "string":
        if (/[\u0000-\u001f\u007f#$]/.test(v) || v.includes("{{") || v !== v.trim())
            throw new Error("serialize: texto não aceito no hyprlang")
        return v
    default:
        throw new Error("serialize: tipo não aceito no hyprlang")
    }
}

// One argument for a shell command line (hypridle and exec run their
// commands through sh): between single quotes, a quote inside as '\''. Rule:
// every text that goes into a command passes here, and then confValue()
function shellQuote(s) {
    if (typeof s !== "string")
        throw new Error("serialize: só texto vai para o shell")
    return "'" + s.replace(/'/g, "'\\''") + "'"
}

// A screen's port name (the shape of settings/monitors.js NAME: never a
// number or a selector word)
function monitorName(name) {
    if (typeof name !== "string" || name.length > 32 || !/^[A-Za-z]+(-[A-Za-z0-9]+)*-[0-9]{1,3}$/.test(name)
            || ["current", "next", "prev", "l", "r", "u", "d", "left", "right", "up", "down", "desc"].includes(name.toLowerCase()))
        throw new Error("serialize: nome de monitor inválido")
    return name
}

// A file the shell writes (the write follows a link): the command that says
// whether it may be written. Exit 0: a plain file; WRITE_MISSING: missing,
// in a folder that is there and can be written. Anything else (a link,
// another kind of file, a folder that cannot be reached, the command not
// starting or running out of time) means no
var WRITE_MISSING = 10
var WRITE_CHECK = 'if [ -L "$1" ]; then exit 3; elif [ -e "$1" ]; then [ -f "$1" ] || exit 3; '
    + 'else d="${1%/*}"; [ -d "$d" ] && [ -w "$d" ] && [ -x "$d" ] || exit 4; exit 10; fi'
function writeCheck(path) {
    if (typeof path !== "string" || !path.startsWith("/"))
        throw new Error("serialize: caminho inválido")
    return ["sh", "-c", WRITE_CHECK, "sh", path]
}
function mayWrite(code) {
    return code === 0 || code === WRITE_MISSING
}

function desktopId(id) {
    if (typeof id !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,95}\.desktop$/.test(id))
        throw new Error("serialize: app inválido")
    return id
}
