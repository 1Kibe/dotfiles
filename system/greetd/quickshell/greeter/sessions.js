.pragma library

// Login sessions from the .desktop files of /usr/share/wayland-sessions and
// /usr/share/xsessions (GreeterState reads them; nothing else is trusted).
// Pure JavaScript, so it is tested without a screen.
//
// The Exec line follows the Desktop Entry spec, without a shell: arguments
// split on spaces, double quotes group, and inside quotes only \" \` \$ \\
// are escapes. Anything the spec says must be quoted (reserved characters)
// found unquoted, a stray backslash, an unknown %-code, an empty line or a
// first word starting with "-" and the entry is refused. An X11 session also
// may not have a loose "--": startx would take the rest as X server options.

const reserved = /[\t\n'\\><~|&;$*?#()`]/
const fieldCodes = ["%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%i", "%c", "%k", "%v", "%m"]

// Values of the [Desktop Entry] group; Name in pt_BR or pt when there is one
function parseDesktop(text) {
    if (typeof text !== "string")
        return null
    const entry = {}
    let names = {}
    let inGroup = false
    for (const raw of text.split("\n")) {
        const line = raw.replace(/\r$/, "")
        if (/^\s*(#|$)/.test(line))
            continue
        const group = line.match(/^\[(.*)\]\s*$/)
        if (group) {
            inGroup = group[1] === "Desktop Entry"
            continue
        }
        if (!inGroup)
            continue
        const kv = line.match(/^([A-Za-z0-9-]+)(\[[^\]]*\])?\s*=\s*(.*)$/)
        if (!kv)
            continue
        const key = kv[1]
        const locale = kv[2] ? kv[2].slice(1, -1) : ""
        const value = unescapeValue(kv[3])
        if (key === "Name") {
            names[locale] = value
        } else if (!locale && !(key in entry)) {
            entry[key] = value
        }
    }
    entry.Name = names["pt_BR"] ?? names["pt"] ?? names[""] ?? ""
    return entry
}

// \s \n \t \r \\ in a value (the Exec quoting comes after, in tokenize)
function unescapeValue(value) {
    return value.replace(/\\([sntr\\])/g, (m, c) => ({ s: " ", n: "\n", t: "\t", r: "\r", "\\": "\\" })[c])
}

// Exec line → list of arguments, or null when it is not plain enough
function tokenize(exec) {
    if (typeof exec !== "string")
        return null
    const args = []
    let current = ""
    let started = false
    let quoted = false
    for (let i = 0; i < exec.length; i++) {
        const c = exec[i]
        if (quoted) {
            if (c === "\\") {
                const next = exec[i + 1]
                if (next === "\"" || next === "`" || next === "$" || next === "\\") {
                    current += next
                    i++
                    continue
                }
                return null
            }
            if (c === "\"") {
                quoted = false
                continue
            }
            current += c
            continue
        }
        if (c === " ") {
            if (started) {
                args.push(current)
                current = ""
                started = false
            }
            continue
        }
        if (c === "\"") {
            quoted = true
            started = true
            continue
        }
        if (reserved.test(c))
            return null
        current += c
        started = true
    }
    if (quoted)
        return null
    if (started)
        args.push(current)

    // %-codes: a whole-word field code goes away (a session gets no files);
    // %% is a literal %; any other % is refused
    const out = []
    for (const arg of args) {
        if (fieldCodes.includes(arg))
            continue
        const rest = arg.replace(/%%/g, "")
        if (rest.includes("%"))
            return null
        out.push(arg.replace(/%%/g, "%"))
    }
    if (out.length === 0 || out[0] === "" || out[0].startsWith("-"))
        return null
    return out
}

// One .desktop file → { id, name, command, tryExec } or null (hidden,
// not shown, not runnable). kind: "wayland" | "x11"; X11 sessions start their
// own X server through startx.
function session(fileName, text, kind) {
    if (kind !== "wayland" && kind !== "x11")
        return null
    if (typeof fileName !== "string" || !/^[A-Za-z0-9._-]+\.desktop$/.test(fileName))
        return null
    const entry = parseDesktop(text)
    if (!entry || entry.Hidden === "true" || entry.NoDisplay === "true")
        return null
    const args = tokenize(entry.Exec)
    if (!args || (kind === "x11" && args.includes("--")))
        return null
    const name = entry.Name !== "" ? entry.Name : fileName.replace(/\.desktop$/, "")
    return {
        id: `${kind}:${fileName}`,
        name: name,
        command: kind === "x11" ? ["startx", "/usr/bin/env"].concat(args) : args,
        tryExec: entry.TryExec ?? ""
    }
}

// greetd 0.10 joins the command's words with spaces and runs
// `[ -f /etc/profile ] && . /etc/profile; …; exec <words>` through /bin/sh -c:
// each word goes in single quotes, so nothing in it is read by that shell
function shellQuote(args) {
    if (!Array.isArray(args))
        return []
    return args.map(a => "'" + String(a).replace(/'/g, "'\\''") + "'")
}
