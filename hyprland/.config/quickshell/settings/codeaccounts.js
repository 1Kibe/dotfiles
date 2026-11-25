.pragma library

// The accounts gh and glab know, read from their own output, and the
// command that switches gh's active account. Plain JS: read by the shell
// and by the tests. The model keeps only { host, users: [{ login, active }] }:
// tokens, scopes, file paths and every other field are dropped where they
// are read, and a host or login that does not fit its pattern is dropped
// too, so nothing else from the output ever reaches the screen.

var MAX_HOSTS = 8
var MAX_USERS = 8
// Longer output is not an account list: nothing is read from it
var MAX_TEXT = 65536

// Labels of letters, digits and inner hyphens, one dot between them, at
// least one dot, 253 at most
var HOST_RE = /^(?=.{1,253}$)[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$/
var LOGIN_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/

function validHost(s) {
    return typeof s === "string" && HOST_RE.test(s)
}

function validLogin(s) {
    return typeof s === "string" && LOGIN_RE.test(s)
}

// Adds one account to the model, within the limits: a host or login
// outside the rules, a repeated login or a second active one are not kept
function add(model, host, login, active) {
    if (!validHost(host) || !validLogin(login))
        return
    let entry = null
    for (const e of model) {
        if (e.host === host)
            entry = e
    }
    if (entry === null) {
        if (model.length >= MAX_HOSTS)
            return
        entry = { host: host, users: [] }
        model.push(entry)
    }
    if (entry.users.some(u => u.login === login))
        return
    const on = active === true && !entry.users.some(u => u.active)
    if (entry.users.length >= MAX_USERS) {
        // Full: the active one still gets in, in the place of the last of
        // the others (without it, every account would look switchable)
        if (!on)
            return
        entry.users[entry.users.length - 1] = { login: login, active: true }
        return
    }
    entry.users.push({ login: login, active: on })
}

// Only hosts with at least one account
function done(model) {
    return model.filter(e => e.users.length > 0)
}

function parseJson(text) {
    if (typeof text !== "string" || text.length === 0 || text.length > MAX_TEXT)
        return null
    try {
        return JSON.parse(text)
    } catch (e) {
        return null
    }
}

// gh auth status --json hosts: { hosts: { <host>: [{ host, login, active, ... }] } }
function parseGhJson(text) {
    const data = parseJson(text)
    const model = []
    if (data === null || typeof data !== "object" || data.hosts === null || typeof data.hosts !== "object"
            || Array.isArray(data.hosts))
        return model
    for (const host of Object.keys(data.hosts)) {
        const list = data.hosts[host]
        if (!Array.isArray(list))
            continue
        for (const e of list) {
            if (e !== null && typeof e === "object")
                add(model, host, e.login, e.active === true)
        }
    }
    return done(model)
}

// gh auth status as text: a line per account (the logged-in phrase or one
// of the failure phrases, then the site and the account; GH_ACCOUNT lists
// them), then the active-account line (GH_ACTIVE).
// Read from the line as it came (the Job asks for no colors): only at the
// start of the line, after gh's mark at most, and a host or login with a
// color code or a control character inside is not kept
var GH_ACCOUNT = /^\s*(?:\S{1,3}\s+)?(?:Logged in to|Failed to log in to|Timeout trying to log in to|Token for|Refresh token for) (\S+) account (\S+)(?:\s|$)/
var GH_ACTIVE = /^\s*- Active account: (true|false)\s*$/
function parseGhText(text) {
    const model = []
    if (typeof text !== "string" || text.length > MAX_TEXT)
        return model
    const accounts = []
    for (const line of text.split("\n")) {
        const a = GH_ACCOUNT.exec(line)
        if (a !== null) {
            accounts.push({ host: a[1], login: a[2], active: false })
            continue
        }
        const on = GH_ACTIVE.exec(line)
        if (on !== null && accounts.length > 0)
            accounts[accounts.length - 1].active = on[1] === "true"
    }
    for (const a of accounts)
        add(model, a.host, a.login, a.active)
    return done(model)
}

// glab auth status: --output json ({ hosts: [{ host, state, user, ... }] })
// or the text (one line per site with the site and the user, as
// GLAB_ACCOUNT reads it); one account per site, the active one
var GLAB_ACCOUNT = /^\s*(?:\S{1,3}\s+)?Logged in to (\S+) as (\S+)(?:\s|$)/
function parseGlab(text) {
    const model = []
    if (typeof text !== "string" || text.length > MAX_TEXT)
        return model
    if (text.trim().startsWith("{")) {
        const data = parseJson(text.trim())
        if (data === null || typeof data !== "object" || !Array.isArray(data.hosts))
            return model
        for (const e of data.hosts) {
            if (e !== null && typeof e === "object" && e.state === "success" && !model.some(m => m.host === e.host))
                add(model, e.host, e.user, true)
        }
        return done(model)
    }
    for (const line of text.split("\n")) {
        const a = GLAB_ACCOUNT.exec(line)
        if (a !== null && !model.some(m => m.host === a[1]))
            add(model, a[1], a[2], true)
    }
    return done(model)
}

// The argv that makes login the active account of host, only for a pair
// of the reading that is on the screen (known) and not already active;
// anything else: null, and nothing runs
function switchCommand(known, host, login) {
    if (!Array.isArray(known) || !validHost(host) || !validLogin(login))
        return null
    for (const e of known) {
        if (e === null || typeof e !== "object" || e.host !== host || !Array.isArray(e.users))
            continue
        for (const u of e.users) {
            if (u !== null && typeof u === "object" && u.login === login && u.active !== true)
                return ["gh", "auth", "switch", "--hostname", host, "--user", login]
        }
    }
    return null
}

// ── Photos ──
// A GitHub login as it can go into github.com/<login>.png: letters,
// digits and inner hyphens, at most 39 (no dot, no underscore: either
// would make another path)
var GITHUB_PHOTO_LOGIN = /^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/
function validGithubPhotoLogin(s) {
    return typeof s === "string" && GITHUB_PHOTO_LOGIN.test(s)
}

// Where an account's photo comes from: only github.com, by its exact
// name. gitlab.com has no public path to a user's photo without a token,
// and any other host is never asked: those keep the initials
function photoTarget(host, login) {
    if (host === "github.com" && validGithubPhotoLogin(login))
        return { kind: "github", login: login }
    return null
}

// The text whose hash names the photo in the cache: host|login, the login
// in lower case (GitHub logins are not case sensitive); "" without a photo
function cacheKeyText(host, login) {
    const t = photoTarget(host, login)
    return t === null ? "" : host + "|" + t.login.toLowerCase()
}
