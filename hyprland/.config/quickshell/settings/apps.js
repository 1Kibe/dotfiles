.pragma library

// Configurações → Apps padrão and Iniciar com o sistema, the parts with no
// state. Plain JS: read by state/AppsState and by the tests.
//
// The apps come from a scan of the .desktop files (state/AppsState) that
// reads only the [Desktop Entry] group and only these keys: Name, Type,
// Hidden, NoDisplay, MimeType, Categories, Terminal and Icon. Exec, TryExec
// and Path are never read, shown or run: an app is opened by its id through
// a fixed launcher (hypr/modules/actions.lua). Every name and type is
// checked here before it is shown or used.

var DESKTOP_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,95}\.desktop$/
var MIME = /^[a-z][a-z0-9-]{0,30}\/[a-z0-9][a-z0-9.+_-]{0,100}$/
// Control characters, the ones that turn the text's direction around, line
// and paragraph separators and the invisible ones (zero width, soft hyphen,
// fillers, variation selectors, BOM, tags)
var BAD_TEXT = /[\u0000-\u001f\u007f-\u009f\u00ad\u034f\u061c\u180e\u200b-\u200f\u2028-\u202e\u2060-\u2064\u2066-\u206f\u3164\ufe00-\ufe0f\ufeff\uffa0]|\udb40[\udc00-\udc7f]/
var ICON = /^[A-Za-z0-9._-]{1,64}$/
var MAX_APPS = 500
var MAX_BATCH = 16
var MAX_TYPES = 64
// The scan's output read at most (whole lines only)
var MAX_SCAN = 1024 * 1024

// Camera RAW types (shared-mime-info names): out of "Imagens", in "Fotos RAW"
var RAW = ["image/x-adobe-dng", "image/x-canon-cr2", "image/x-canon-cr3", "image/x-canon-crw", "image/x-fuji-raf",
           "image/x-kodak-dcr", "image/x-minolta-mrw", "image/x-nikon-nef", "image/x-nikon-nrw", "image/x-olympus-orf",
           "image/x-panasonic-rw2", "image/x-pentax-pef", "image/x-sigma-x3f", "image/x-sony-arw", "image/x-sony-sr2",
           "image/x-sony-srf", "image/x-dcraw"]
var SVG = ["image/svg+xml", "image/svg+xml-compressed"]

// Settings key -> what it covers: a fixed list of types, or a prefix (every
// type the app declares under it, minus the ones another key owns). The
// install gives defaults only to the PDF, Documentos and Planilhas rows
// (install.sh), and the browser.
var KEYS = [
    { key: "appBrowser", label: "Navegador", types: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html",
                                                    "application/xhtml+xml"] },
    { key: "appFiles", label: "Arquivos", types: ["inode/directory"] },
    { key: "appTerminal", label: "Terminal", terminal: true },
    { key: "appImages", label: "Imagens", prefix: "image/", except: RAW.concat(SVG) },
    { key: "appVideos", label: "Vídeos", prefix: "video/" },
    { key: "appMusic", label: "Músicas", prefix: "audio/" },
    { key: "appText", label: "Texto", types: ["text/plain"] },
    { key: "appPdf", label: "PDF", types: ["application/pdf"] },
    { key: "appDocs", label: "Documentos", types: ["application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                                  "application/msword", "application/vnd.oasis.opendocument.text",
                                                  "application/rtf", "text/rtf"] },
    { key: "appSheets", label: "Planilhas", types: ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                                   "application/vnd.ms-excel", "application/vnd.oasis.opendocument.spreadsheet",
                                                   "text/csv"] },
    { key: "appSlides", label: "Apresentações", types: ["application/vnd.openxmlformats-officedocument.presentationml.presentation",
                                                       "application/vnd.oasis.opendocument.presentation",
                                                       "application/vnd.ms-powerpoint"] },
    { key: "appVector", label: "Imagens vetoriais", types: SVG },
    { key: "appRaw", label: "Fotos RAW", types: RAW },
    { key: "appCad", label: "Desenhos técnicos", types: ["image/vnd.dxf", "image/x-dxf"] }
]
// The rows that only show when some installed app opens them
var OPTIONAL = ["appDocs", "appSheets", "appSlides", "appVector", "appRaw", "appCad"]

function own(o, k) {
    return o !== null && typeof o === "object" && Object.prototype.hasOwnProperty.call(o, k)
}
function text(v, max) {
    return typeof v === "string" && v.length > 0 && v.length <= max && !BAD_TEXT.test(v)
}
function list(v) {
    return String(v || "").split(";").map(s => s.trim()).filter(s => s.length > 0)
}

// Where an app comes from, by its folder (one of state/AppsState folders):
// Flatpak's exports by their path (they may also be in XDG_DATA_DIRS), the
// first folder is the user's, the others the system's
function origin(dir, folders) {
    const i = folders.indexOf(dir)
    if (i < 0)
        return ""
    if (dir.endsWith("/flatpak/exports/share/applications"))
        return "Flatpak"
    if (i === 0)
        return "sua pasta"
    return "sistema"
}

// One line of the scan: "folder<TAB>id<TAB>Name<TAB>Type<TAB>Hidden<TAB>
// NoDisplay<TAB>MimeType<TAB>Categories<TAB>Terminal<TAB>Icon" → an app, or
// null. `folders`: the scanned folders, in order
function app(line, folders) {
    const f = String(line).split("\t")
    if (f.length !== 10)
        return null
    const [dir, id, name, type, hidden, noDisplay, mime, categories, terminal, icon] = f
    const from = origin(dir, folders || [])
    if (from === "")
        return null
    if (!DESKTOP_ID.test(id) || !text(name, 64) || type !== "Application")
        return null
    if (hidden === "true" || noDisplay === "true")
        return null
    return {
        id: id,
        name: name,
        origin: from,
        shadows: false,
        types: list(mime).filter(t => MIME.test(t)).slice(0, MAX_TYPES),
        categories: list(categories).filter(c => /^[A-Za-z0-9_-]{1,40}$/.test(c)),
        terminal: terminal === "true",
        icon: ICON.test(icon) ? icon : ""
    }
}

// The scan's output → the apps (first id wins: the user's folder comes first;
// one that hides an app of the same id from the system or Flatpak says so),
// at most MAX_APPS, sorted by name. Output past MAX_SCAN is not read
function parseScan(out, folders) {
    let text = String(out)
    if (text.length > MAX_SCAN)
        text = text.slice(0, text.lastIndexOf("\n", MAX_SCAN) + 1)
    const seen = {}
    const apps = []
    for (const line of text.split("\n")) {
        const a = app(line, folders)
        if (a === null)
            continue
        if (seen[a.id]) {
            if (seen[a.id].origin === "sua pasta" && a.origin !== "sua pasta")
                seen[a.id].shadows = true
            continue
        }
        if (apps.length >= MAX_APPS)
            continue
        seen[a.id] = a
        apps.push(a)
    }
    return apps.sort((x, y) => x.name.localeCompare(y.name))
}

// How an app reads in a list: its name, where it comes from, and the note
// when the user's copy hides the system's
function describe(a) {
    if (!a)
        return ""
    return a.origin + (a.shadows ? " · esconde o do sistema" : "")
}

function spec(key) {
    return KEYS.find(k => k.key === key) || null
}

// The types of `key` this app declares (empty: it does not serve the key)
function typesFor(key, a) {
    const k = spec(key)
    if (!k || !a)
        return []
    if (k.terminal)
        return []
    if (k.prefix)
        return a.types.filter(t => t.startsWith(k.prefix) && !(k.except || []).includes(t))
    return a.types.filter(t => k.types.includes(t))
}
function serves(key, a) {
    const k = spec(key)
    if (!k || !a)
        return false
    if (k.terminal)
        return a.categories.includes("TerminalEmulator") && !a.terminal
    return typesFor(key, a).length > 0
}
function candidates(key, apps) {
    return apps.filter(a => serves(key, a))
}

// The xdg-mime commands that make `a` the default of `key`: the types it
// declares, in batches of MAX_BATCH; [] when it does not serve the key
function xdgArgs(key, a) {
    if (!a || !DESKTOP_ID.test(a.id))
        return []
    const k = spec(key)
    const types = typesFor(key, a)
    const out = []
    for (let i = 0; i < types.length; i += MAX_BATCH)
        out.push(["xdg-mime", "default", a.id].concat(types.slice(i, i + MAX_BATCH)))
    return out
}

// The type asked to `xdg-mime query default` for a row (what the page shows)
function queryType(key) {
    const k = spec(key)
    if (!k || k.terminal)
        return ""
    if (k.prefix)
        return { "image/": "image/png", "video/": "video/mp4", "audio/": "audio/mpeg" }[k.prefix] || ""
    return k.types[0]
}
// Its answer: a desktop id, or ""
function queryResult(out) {
    const v = String(out).trim()
    return DESKTOP_ID.test(v) ? v : ""
}

// Iniciar com o sistema: who may be added (Terminal=true, Hidden, NoDisplay
// and non-Applications are already out of the scan)
function startable(apps) {
    return apps.filter(a => !a.terminal)
}

// The generated Lua data (no command, only ids); `lua`: serialize.js luaValue.
// Ids not passing DESKTOP_ID are dropped
function appsLua(terminal, files, lua) {
    const pick = id => typeof id === "string" && DESKTOP_ID.test(id) ? id : ""
    return "-- Generated by the shell (Configurações → Apps padrão): only ids, read by\n"
           + "-- modules/actions.lua for Super+Enter and Super+E. Change it there.\n"
           + `return { terminal = ${lua(pick(terminal))}, files = ${lua(pick(files))} }\n`
}
function autostartLua(artcraft, ids, lua) {
    const good = (Array.isArray(ids) ? ids : []).filter(id => typeof id === "string" && DESKTOP_ID.test(id)).slice(0, 16)
    return "-- Generated by the shell (Configurações → Iniciar com o sistema): only ids,\n"
           + "-- read by modules/autostart.lua at login. Change it there.\n"
           + `return { artcraft = ${lua(artcraft === true)}, apps = { ${good.map(id => lua(id)).join(", ")} } }\n`
}
