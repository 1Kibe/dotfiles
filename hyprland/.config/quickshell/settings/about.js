.pragma library

// Configurações → Sobre, the parts with no state: what the system and the
// repo's git say, read as data only (every value passes a pattern or is cut
// to a short plain text, else "—"), and what Exportar takes to the repo's
// defaults.json. Plain JS: read by state/AboutState, state/SettingsStore and
// the tests. Nothing here is ever run.

var NONE = "—"
// Control characters, direction marks, separators and invisible ones
var BAD_TEXT = /[\u0000-\u001f\u007f-\u009f\u061c\u200b-\u200f\u2028\u2029\u202a-\u202e\u2066-\u2069\ufeff]/

// A short plain text (at most 64 characters, nothing that is not shown as
// typed), or "—"
function text(v) {
    const t = String(v === undefined || v === null ? "" : v).trim()
    if (t === "" || BAD_TEXT.test(t))
        return NONE
    return t.length > 64 ? t.slice(0, 63) + "…" : t
}
function pattern(v, re) {
    const t = String(v === undefined || v === null ? "" : v).trim()
    return re.test(t) ? t : NONE
}

// ── git (only these four answers) ──
function gitHash(out) { return pattern(out, /^[0-9a-f]{7,40}$/) }
function gitDate(out) { return pattern(out, /^\d{4}-\d{2}-\d{2}$/) }
function gitRef(out) { return pattern(out, /^[A-Za-z0-9._\/-]{1,60}$/) }

// ── The system ──
// /etc/os-release, read by pattern (never sourced): the pretty name, else
// NAME and VERSION_ID
function osName(release) {
    const get = key => {
        const m = new RegExp(`^${key}=(?:"([^"\\n]*)"|'([^'\\n]*)'|([^\\n]*))$`, "m").exec(String(release))
        return m ? (m[1] !== undefined ? m[1] : m[2] !== undefined ? m[2] : m[3]) : ""
    }
    const pretty = get("PRETTY_NAME")
    if (pretty !== "")
        return text(pretty)
    return text([get("NAME"), get("VERSION_ID")].filter(s => s !== "").join(" "))
}
function kernel(out) { return pattern(out, /^[0-9A-Za-z._+-]{1,64}$/) }
// The first "model name" of /proc/cpuinfo
function cpuModel(info) {
    const m = /^model name\s*:\s*(.*)$/m.exec(String(info))
    return m ? text(m[1].replace(/\s+/g, " ")) : NONE
}
// MemTotal of /proc/meminfo, in GB with one decimal
function memory(info) {
    const m = /^MemTotal:\s*(\d{1,12})\s*kB$/m.exec(String(info))
    if (!m)
        return NONE
    const gb = parseInt(m[1], 10) / 1024 / 1024
    return `${gb.toFixed(1).replace(".", ",")} GB`
}
// `hyprctl version -j`: its tag (or version)
function hyprland(out) {
    let d = null
    try {
        d = JSON.parse(out)
    } catch (e) {
        return NONE
    }
    if (d === null || typeof d !== "object")
        return NONE
    return pattern(d.tag || d.version || "", /^v?[0-9][0-9A-Za-z._+-]{0,30}$/)
}
// `quickshell --version`: the first version number in its first line
function quickshell(out) {
    const m = /\b(\d+\.\d+(?:\.\d+)?)\b/.exec(String(out).split("\n")[0])
    return m ? m[1] : NONE
}

// ── Exportar ──
// The keys with a source list that may still be exported: none of them is
// machine, all of them hold a name from a list that the install puts on
// every machine (fonts and cursor themes)
var EXPORTED_SOURCES = ["fontUi", "fontMono", "fontPanels", "cursorTheme"]

// A path that may go to the repo: the schema's default, or inside the
// wallpapers the repo installs (~/.config/wallpapers/)
function releasedPath(spec, value, home) {
    if (value === spec.def)
        return true
    const v = String(value)
    const inside = p => !p.split("/").includes("..")
    if (v.startsWith("~/.config/wallpapers/") && inside(v))
        return true
    return typeof home === "string" && home !== "" && v.startsWith(`${home}/.config/wallpapers/`) && inside(v)
}

// What Exportar writes: { out, changed, skipped }. `keys`: schema KEYS;
// `values`: the current values; `defaults`: what defaults.json has now;
// `validate`: validate.js validate; `home`: the home folder. Only keys that are
// not machine ones; each value checked again; a path not released keeps the
// repo's value and is listed in `skipped`. `changed`: the keys whose value in
// defaults.json would change
function exportPlan(keys, values, defaults, validate, home) {
    const out = {}
    const changed = []
    const skipped = []
    for (const key of Object.keys(keys).sort()) {
        const spec = keys[key]
        if (spec.machine)
            continue
        let v = values[key]
        const ok = validate(spec, v, home).ok
        if (!ok) {
            skipped.push(key)
            v = defaults[key]
        } else if (spec.type === "path") {
            const asHome = typeof v === "string" && typeof home === "string" && home !== "" && v.startsWith(home + "/")
                           ? "~" + v.slice(home.length) : v
            if (!releasedPath(spec, asHome, home)) {
                skipped.push(key)
                v = defaults[key]
            } else {
                v = asHome
            }
        }
        out[key] = v
        if (JSON.stringify(v) !== JSON.stringify(defaults[key]))
            changed.push(key)
    }
    return { out: out, changed: changed, skipped: skipped }
}

// For the tests: the keys that would leak a machine's own value by being exported
// (a list source, a screen or app pattern) without being machine ones, the
// named exceptions aside. Paths are not listed: exportPlan never takes one
// outside the default or the wallpapers folder. `machinePatterns`: the
// schema's screen and app patterns (their source text is compared). [] when
// fine
function leaks(keys, machinePatterns) {
    const mine = (machinePatterns || []).map(p => String(p))
    const out = []
    for (const [key, spec] of Object.entries(keys)) {
        if (spec.machine || EXPORTED_SOURCES.includes(key))
            continue
        if (spec.source !== undefined || (spec.pattern && mine.includes(String(spec.pattern))))
            out.push(key)
    }
    return out
}
