.pragma library
.import "../lock/text.js" as Clean
.import "codeaccounts.js" as Accounts

// The git side of the code accounts: profiles (who signs the commits and
// which SSH key pushes) and folders (where a profile applies), checked
// here and turned into the text of the files the shell writes under
// ~/.config/git/. Plain JS: read by the shell and by the tests. Anything
// that does not pass is refused, never escaped into place: git runs
// core.sshCommand through a shell, and a folder ends up inside a section
// header. Errors carry a fixed message, never the value.

var PROFILE_MAX = 8
var FOLDER_MAX = 32
var NAME_MAX = 100
var EMAIL_MAX = 254
var LABEL_MAX = 40

var HEADER = "# Written by the shell; rewritten at every change.\n"

var ID_RE = /^p[1-8]$/
// A key is a file name in ~/.ssh, never a path
var KEY_RE = /^[A-Za-z0-9][A-Za-z0-9._@+-]{0,63}$/
var KEY_NOT = /^(config|environment|known_hosts.*|authorized_keys.*)$|\.(pub|old|bak)$/
var EMAIL_RE = /^[^\s@"\\]+@[^\s@"\\]+\.[^\s@"\\]+$/
// A home the generated text can name: absolute, plain characters only
var HOME_RE = /^\/[A-Za-z0-9._\/-]+$/
// One folder segment: no space, no git wildcard, no quote or backslash
var SEGMENT_RE = /^[A-Za-z0-9._@+-]+$/
// Folders a profile never applies to (the home itself is refused apart)
var FOLDER_NOT = ["~/.ssh", "~/.config", "~/.gnupg"]

function validKey(name) {
    return typeof name === "string" && KEY_RE.test(name) && !KEY_NOT.test(name) && name !== "." && name !== ".."
}

// A text for the commit: present, within max, no control, direction or
// invisible character (lock/text.js), not only spaces
function validText(s, max) {
    return typeof s === "string" && s.length > 0 && s.length <= max && s.trim() !== "" && !Clean.BAD.test(s)
}

function validEmail(s) {
    return validText(s, EMAIL_MAX) && EMAIL_RE.test(s)
}

// "" or github.com|<login>: the GitHub account whose photo the profile
// shows (never written to a git file)
function validGhAccount(s) {
    if (s === "")
        return true
    if (typeof s !== "string" || !s.startsWith("github.com|"))
        return false
    return Accounts.validGithubPhotoLogin(s.slice("github.com|".length))
}

function validProfile(p) {
    return p !== null && typeof p === "object" && !Array.isArray(p) && typeof p.id === "string" && ID_RE.test(p.id)
        && validText(p.label, LABEL_MAX) && validText(p.name, NAME_MAX) && validEmail(p.email) && validKey(p.key)
        && (p.ghAccount === undefined || validGhAccount(p.ghAccount))
}

// A folder as typed (~/x, or an absolute path inside home) in its stored
// form: "~/a/b", no trailing slash; "" when it is not a folder a profile
// can have: outside home, the home itself, ~/.ssh, ~/.config, ~/.gnupg or
// below them, a "." or ".." segment, an empty one, or any character
// outside SEGMENT_RE
function normalFolder(text, home) {
    if (typeof text !== "string" || text.length === 0 || text.length > 4096 || !validHome(home))
        return ""
    let rest
    if (text === "~" || text.startsWith("~/"))
        rest = text.slice(1)
    else if (text === home || text.startsWith(home + "/"))
        rest = text.slice(home.length)
    else
        return ""
    const parts = rest.split("/").filter((s, i, a) => !(s === "" && i === a.length - 1))
    if (parts.length < 2 || parts[0] !== "")
        return ""
    for (const s of parts.slice(1)) {
        if (s === "" || s === "." || s === ".." || !SEGMENT_RE.test(s))
            return ""
    }
    const folder = "~/" + parts.slice(1).join("/")
    for (const no of FOLDER_NOT) {
        if (folder === no || folder.startsWith(no + "/"))
            return ""
    }
    return folder
}

function validHome(home) {
    return typeof home === "string" && HOME_RE.test(home) && home.length > 1 && !home.endsWith("/")
        && !home.split("/").some(s => s === "." || s === "..")
}

// A folder entry ({ path, profile }) in its stored form, with a profile
// of the list
function validFolder(f, profiles, home) {
    return f !== null && typeof f === "object" && !Array.isArray(f) && typeof f.path === "string"
        && normalFolder(f.path, home) === f.path && Array.isArray(profiles)
        && profiles.some(p => validProfile(p) && p.id === f.profile)
}

function depth(folder) {
    return folder.split("/").length
}

// The folders that sit inside another one with a different profile (the
// deeper one wins in git; the page says so)
function nested(folders) {
    const out = []
    for (const f of folders) {
        if (folders.some(o => o !== f && f.path.startsWith(o.path + "/") && o.profile !== f.profile))
            out.push(f.path)
    }
    return out
}

// A value between quotes in a git file: \ and " escaped. Only for texts
// that passed validText (no line breaks, no control characters)
function quoted(s) {
    return "\"" + s.replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
}

// ~/.config/git/contas.conf: one includeIf per folder whose profile is in
// the list, the shallower first so the deeper one wins, and the HTTPS
// credentials from gh and glab for github.com and gitlab.com
function contasConf(profiles, folders, home) {
    if (!Array.isArray(profiles) || !Array.isArray(folders) || profiles.length > PROFILE_MAX || folders.length > FOLDER_MAX
            || !validHome(home) || !profiles.every(validProfile))
        throw new Error("invalid code accounts")
    const seen = {}
    for (const f of folders) {
        if (!validFolder(f, profiles, home) || seen[f.path])
            throw new Error("invalid code accounts")
        seen[f.path] = true
    }
    const ids = {}
    for (const p of profiles) {
        if (ids[p.id])
            throw new Error("invalid code accounts")
        ids[p.id] = true
    }
    const order = folders.slice().sort((a, b) => depth(a.path) - depth(b.path) || (a.path < b.path ? -1 : a.path > b.path ? 1 : 0))
    let text = HEADER
    for (const f of order)
        text += "[includeIf \"gitdir:" + f.path + "/\"]\n\tpath = contas/" + f.profile + ".conf\n"
    text += "[credential \"https://github.com\"]\n\thelper =\n\thelper = !gh auth git-credential\n"
    text += "[credential \"https://gitlab.com\"]\n\thelper =\n\thelper = !glab auth git-credential\n"
    return text
}

// ~/.config/git/contas/<id>.conf: who signs and which key pushes. The
// command is always the same, only the checked key path changes
function profileConf(profile, home) {
    if (!validProfile(profile) || !validHome(home))
        throw new Error("invalid code accounts")
    return HEADER
        + "[user]\n\tname = " + quoted(profile.name) + "\n\temail = " + quoted(profile.email) + "\n"
        + "[core]\n\tsshCommand = ssh -i " + home + "/.ssh/" + profile.key + " -o IdentitiesOnly=yes\n"
}

// A profile removed: its file stays, with the header only
function emptyConf() {
    return HEADER
}
