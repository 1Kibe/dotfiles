.pragma library
.import "../lock/text.js" as Clean

// The long lists of the control center (and of the bar's panels, which use
// the same components). Plain JS: read by the shell and by the tests.

var VISIBLE = 5        // networks shown before "Mostrar mais N redes"
var SEARCH_FROM = 9    // the search shows from this many networks on

// A name from outside as shown: no control, direction or invisible
// characters, one line, at most 64 characters (see lock/text.js)
function trim(text) {
    return Clean.clean(text, 64)
}

// A list from Quickshell (a model's values: list-like, not a JS Array) or
// a JS Array, as a JS Array; anything else is empty. Array.isArray alone
// would turn every real model into an empty list.
function toList(x) {
    if (Array.isArray(x))
        return x
    const out = []
    if (x !== null && x !== undefined && typeof x !== "string" && typeof x.length === "number") {
        const n = Math.min(Math.max(0, Math.floor(x.length)), 100000)
        for (let i = 0; i < n; i++)
            out.push(x[i])
    }
    return out
}

// The Wi-Fi networks as listed. list: the device's networks ({ name,
// signalStrength 0..1, known, connected }); opts: { query, showAll,
// minSignal }. Out: the ones with no name and the ones below minSignal
// (the connected one always stays). Order: the connected one, then the
// saved ones, then by signal. The first VISIBLE unless showAll or a search;
// the search only once there are SEARCH_FROM or more, matching the name
// as shown, ignoring case. Returns { shown, hidden (how many were left out
// by the cut), search (whether the search field shows) }.
function networks(list, opts) {
    const o = opts || {}
    const min = typeof o.minSignal === "number" ? o.minSignal : 0.2
    const kept = toList(list).filter(n => n && trim(n.name) !== ""
        && (n.connected === true || Number(n.signalStrength) >= min))
    kept.sort((a, b) => (Number(b.connected === true) - Number(a.connected === true))
        || (Number(b.known === true) - Number(a.known === true))
        || (Number(b.signalStrength) - Number(a.signalStrength)))
    const search = kept.length >= SEARCH_FROM
    const q = search ? String(o.query || "").trim().toLowerCase() : ""
    const matched = q === "" ? kept : kept.filter(n => trim(n.name).toLowerCase().includes(q))
    const shown = o.showAll === true || q !== "" ? matched : matched.slice(0, VISIBLE)
    return { shown: shown, hidden: matched.length - shown.length, search: search }
}

// The Wi-Fi list's items for the control center's keyboard, in order: the
// switch (with a Wi-Fi device), the search (when it shows), each network
// shown (a saved one followed by its "Esquecer"), "Mostrar mais" (when some
// are left out), "Outra rede…" (with a Wi-Fi device), "Mais opções…"
function wifiKeys(hasWifi, list, wifiOn) {
    const items = []
    if (hasWifi)
        items.push({ kind: "switch" })
    if (list.search)
        items.push({ kind: "search" })
    list.shown.forEach((n, i) => {
        items.push({ kind: "network", index: i })
        if (n.known === true)
            items.push({ kind: "forget", index: i })
    })
    if (list.hidden > 0)
        items.push({ kind: "more" })
    if (hasWifi && wifiOn !== false)
        items.push({ kind: "other" })
    items.push({ kind: "options" })
    return items
}

// A Wi-Fi password as NetworkManager takes it: 8 to 63 printable ASCII
// characters, or 64 hexadecimal digits (the key itself)
function validPsk(psk) {
    return typeof psk === "string" && (/^[ -~]{8,63}$/.test(psk) || /^[0-9A-Fa-f]{64}$/.test(psk))
}

// How many bytes a text takes in UTF-8; Infinity for one that is not valid
// text (a lone half of a surrogate pair), never an exception
function utf8Bytes(text) {
    try {
        return unescape(encodeURIComponent(String(text))).length
    } catch (e) {
        return Infinity
    }
}

// A hidden network typed by hand: "" when it may go to nmcli, else the
// message to show. The name is refused, never cleaned (a cleaned name would
// join another network than the one typed): 1 to 32 bytes, nothing that
// lists.js trim() would change, no control, direction or invisible
// character (lock/text.js BAD), not starting with "-"
function hiddenCheck(name, psk) {
    if (typeof name !== "string" || name.length === 0 || Clean.BAD.test(name) || utf8Bytes(name) > 32
            || name !== trim(name) || name.charAt(0) === "-")
        return "Nome de rede inválido"
    if (!validPsk(psk))
        return "A senha precisa ter de 8 a 63 caracteres"
    return ""
}

// The grid button's state line: generic words only, never a network's name
// s: { hasWifi, wifiOn, wired, connected, connecting }
function summary(s) {
    if (s.wired)
        return "Cabo conectado"
    if (s.connecting)
        return "Conectando…"
    if (s.connected)
        return "Conectado"
    if (s.hasWifi && !s.wifiOn)
        return "Wi-Fi desligado"
    return "Desconectado"
}

// ── Bluetooth ──

// An address as BlueZ gives it (with ":"), or as its alias falls back to
// it (with "-")
var ADDRESS = /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/

// A device's name as shown (the alias, else the name it announces); ""
// when it only has its address
function deviceName(d) {
    if (!d)
        return ""
    const alias = trim(d.name)
    if (alias !== "" && !ADDRESS.test(alias))
        return alias
    const own = trim(d.deviceName)
    return ADDRESS.test(own) ? "" : own
}
// What a row says: the name, or the address for one with none
function deviceLabel(d) {
    const n = deviceName(d)
    return n !== "" ? n : trim(d ? d.address : "")
}

// The Bluetooth devices as listed. devices: the adapter's ({ name,
// deviceName, address, paired, connected }); opts: { showUnnamed }. mine:
// the paired ones (always on top), the connected first, then by name.
// near: the others with a name, by name, and the ones with none (by
// address) only with showUnnamed. unnamed: how many have no name.
function bluetoothList(devices, opts) {
    const o = opts || {}
    const all = toList(devices).filter(d => d)
    const byName = (a, b) => deviceLabel(a).localeCompare(deviceLabel(b))
    const mine = all.filter(d => d.paired === true || d.connected === true)
    mine.sort((a, b) => (Number(b.connected === true) - Number(a.connected === true)) || byName(a, b))
    const others = all.filter(d => d.paired !== true && d.connected !== true)
    const named = others.filter(d => deviceName(d) !== "").sort(byName)
    const unnamed = others.filter(d => deviceName(d) === "").sort(byName)
    const show = o.showUnnamed === true
    return { mine: mine, near: show ? named.concat(unnamed) : named, unnamed: show ? 0 : unnamed.length }
}

// The Bluetooth list's items for the control center's keyboard, in order:
// the switch (with an adapter), each of mine with its "Esquecer" (paired
// ones), "Procurar", each nearby one, "+ N sem nome", "Mais opções…".
// s: { available, powered, list }
function bluetoothKeys(s) {
    const items = []
    if (s.available)
        items.push({ kind: "switch" })
    if (s.available && s.powered) {
        s.list.mine.forEach((d, i) => {
            items.push({ kind: "mine", index: i })
            if (d.paired === true)
                items.push({ kind: "forget", index: i })
        })
        items.push({ kind: "scan" })
        s.list.near.forEach((d, i) => items.push({ kind: "near", index: i }))
        if (s.list.unnamed > 0)
            items.push({ kind: "unnamed" })
    }
    items.push({ kind: "options" })
    return items
}

// The grid button's state line: generic words only, never a device's name
// s: { available, powered, connected (a count) }
function bluetoothSummary(s) {
    if (!s.available)
        return "Sem Bluetooth"
    if (!s.powered)
        return "Desligado"
    if (s.connected === 1)
        return "1 conectado"
    if (s.connected > 1)
        return `${s.connected} conectados`
    return "Ligado"
}

// ── The mixer (PipeWire) ──

var MAX_STREAMS = 50   // app streams shown (and tracked) at most
// An icon only by a theme name: no path, no URL
var ICON_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/

// A device as shown: the friendliest name it has
function audioDeviceName(n) {
    return n ? trim(n.description || n.nickname || n.name) : ""
}
// An app's stream as shown: the name the app announces, else the node's
function streamName(n) {
    if (!n)
        return ""
    const p = n.properties || {}
    const app = trim(p["application.name"])
    return app !== "" ? app : trim(n.description || n.name)
}
// The theme icon name the app announces, "" for none or one that is not a
// plain name
function streamIcon(n) {
    const p = (n && n.properties) || {}
    const i = typeof p["application.icon-name"] === "string" ? p["application.icon-name"] : ""
    return ICON_NAME.test(i) ? i : ""
}
// A volume as written: 0..1, never above 100%
function clampVolume(v) {
    const x = Number(v)
    return isFinite(x) ? Math.max(0, Math.min(1, x)) : 0
}

// The audio flag of a node's PwNodeType (Audio = 1; AudioSink is 17,
// AudioSource 9, AudioOutStream 21): known before the node is tracked,
// unlike its audio object, which an untracked stream does not have yet
var AUDIO_FLAG = 1

// The mixer's nodes: the output and input devices (not app streams) and the
// apps playing sound (output streams), each by name, the apps cut at
// MAX_STREAMS. nodes: Pipewire.nodes ({ type, isSink, isStream, ... }).
// Returns { sinks, sources, streams, hiddenStreams }.
function mixer(nodes) {
    const all = toList(nodes).filter(n => n && (Number(n.type) & AUDIO_FLAG) === AUDIO_FLAG)
    const byDevice = (a, b) => audioDeviceName(a).localeCompare(audioDeviceName(b))
    const byStream = (a, b) => streamName(a).localeCompare(streamName(b))
    const sinks = all.filter(n => n.isStream !== true && n.isSink === true).sort(byDevice)
    const sources = all.filter(n => n.isStream !== true && n.isSink !== true).sort(byDevice)
    const playing = all.filter(n => n.isStream === true && n.isSink === true).sort(byStream)
    const streams = playing.slice(0, MAX_STREAMS)
    return { sinks: sinks, sources: sources, streams: streams, hiddenStreams: playing.length - streams.length }
}

// The mixer's items for the control center's keyboard, in order: each
// output, the microphone's mute (with a default input), each input, each
// app's mute
function mixerKeys(m, hasSource) {
    const items = []
    m.sinks.forEach((n, i) => items.push({ kind: "sink", index: i }))
    if (hasSource)
        items.push({ kind: "micMute" })
    m.sources.forEach((n, i) => items.push({ kind: "source", index: i }))
    m.streams.forEach((n, i) => items.push({ kind: "stream", index: i }))
    return items
}

// ── Updates (checkupdates, paru -Qua) ──

var UPDATES_SHOWN = 5        // per origin, before "e mais N"
var UPDATES_MAX_LINES = 2000 // more output than this is a failure
var PKG_NAME = /^[a-z0-9@._+][a-z0-9@._+-]{0,63}$/
var PKG_VERSION = /^[A-Za-z0-9:._+~-]{1,40}$/

// One line of checkupdates or paru -Qua: "name old -> new", or the same
// with " [ignored]" (held back by IgnorePkg: still an update, the marker
// left out); a line over 200 characters that starts like one counts as an
// update that is not shown ({ hidden: true }); null for anything else
// (never shown, never counted)
function updateLine(line) {
    if (typeof line !== "string")
        return null
    const parts = line.trim().split(/ +/)
    if (line.length > 200)
        return parts.length >= 4 && PKG_NAME.test(parts[0]) && parts[2] === "->" ? { hidden: true } : null
    if (parts.length === 5 && parts[4] === "[ignored]")
        parts.pop()
    if (parts.length !== 4 || parts[2] !== "->")
        return null
    if (!PKG_NAME.test(parts[0]) || !PKG_VERSION.test(parts[1]) || !PKG_VERSION.test(parts[3]))
        return null
    return { name: parts[0], from: parts[1], to: parts[3] }
}

// The grid button's state line and whether it shows yellow. s: { sys, aur }
// each { state ("idle", "checking", "ok", "failed", "missing"), count }
function updatesSummary(s) {
    const known = o => o && o.count >= 0
    const n = (known(s.sys) ? s.sys.count : 0) + (known(s.aur) ? s.aur.count : 0)
    if (n > 0)
        return { text: n === 1 ? "1 atualização" : `${n} atualizações`, warn: true }
    const checking = (s.sys && s.sys.state === "checking") || (s.aur && s.aur.state === "checking")
    if (checking)
        return { text: "Verificando…", warn: false }
    // "Em dia" only when the system's check came back with nothing
    if (s.sys && s.sys.state === "ok" && s.sys.count === 0)
        return { text: "Sistema em dia", warn: false }
    if (s.sys && s.sys.state === "failed")
        return { text: "Não deu para verificar", warn: false }
    return { text: "Não verificado", warn: false }
}

// ── Tailscale (tailscale status --json) ──

var TS_MAX_PEERS = 500
var TS_MAX_BYTES = 4 * 1024 * 1024
var TS_STATES = ["NoState", "NeedsLogin", "NeedsMachineAuth", "Stopped", "Starting", "Running"]

// A tailnet address: IPv4 in 100.64.0.0/10, or IPv6 under fd7a:115c:a1e0:
function tsAddress(ip) {
    if (typeof ip !== "string" || ip.length > 45)
        return false
    const v4 = /^100\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/.exec(ip)
    if (v4)
        return Number(v4[1]) >= 64 && Number(v4[1]) <= 127 && Number(v4[2]) <= 255 && Number(v4[3]) <= 255
    return /^fd7a:115c:a1e0:[0-9a-f:]{1,30}$/.test(ip)
}

// One node, only the fields of the white list, checked
function tsNode(n) {
    if (!n || typeof n !== "object")
        return null
    const ips = (Array.isArray(n.TailscaleIPs) ? n.TailscaleIPs : []).filter(tsAddress).slice(0, 4)
    const dns = Clean.clean(typeof n.DNSName === "string" ? n.DNSName.replace(/\.$/, "") : "", 63)
    const host = Clean.clean(typeof n.HostName === "string" ? n.HostName : "", 63)
    const seen = typeof n.LastSeen === "string" ? Date.parse(n.LastSeen) : NaN
    return {
        name: host !== "" ? host : dns.split(".")[0] || "",
        ips: ips,
        online: n.Online === true,
        exitNode: n.ExitNode === true,
        exitOption: n.ExitNodeOption === true,
        lastSeen: isFinite(seen) && seen > 0 ? seen : 0
    }
}

// The status as kept: { state (one of TS_STATES, or "unknown"), self,
// peers (at most TS_MAX_PEERS, online first, then by name) }; null for
// text that is not that JSON. Everything else of the status (the login
// address, keys, public addresses, users, health) is never kept.
function tsParse(text) {
    if (typeof text !== "string" || text.length > TS_MAX_BYTES)
        return null
    let d
    try {
        d = JSON.parse(text)
    } catch (e) {
        return null
    }
    if (!d || typeof d !== "object" || Array.isArray(d))
        return null
    const state = TS_STATES.includes(d.BackendState) ? d.BackendState : "unknown"
    const raw = d.Peer && typeof d.Peer === "object" && !Array.isArray(d.Peer) ? Object.keys(d.Peer).slice(0, TS_MAX_PEERS).map(k => d.Peer[k]) : []
    const peers = raw.map(tsNode).filter(p => p !== null)
    peers.sort((a, b) => (Number(b.online) - Number(a.online)) || a.name.localeCompare(b.name))
    return { state: state, self: tsNode(d.Self), peers: peers }
}

// The grid button's state line: generic words only, never a name or an
// address. state: a TS_STATES value, "unknown", or "off" (no answer)
function tsSummary(state, exitActive) {
    if (state === "Running")
        return exitActive ? "Conectado · saída ativa" : "Conectado"
    if (state === "Starting")
        return "Conectando…"
    if (state === "NeedsLogin")
        return "Entre pelo terminal"
    if (state === "NeedsMachineAuth")
        return "Aguardando aprovação"
    if (state === "Stopped")
        return "Desconectado"
    if (state === "timeout")
        return "Não deu para ler"
    if (state === "NoState" || state === "unknown")
        return "Desconhecido"
    if (state === "")
        return ""
    return "Desligado"
}

// "online", "hoje", "ontem", "há N dias" (lastSeen and now in ms)
function tsSeen(online, lastSeen, now) {
    if (online)
        return "online"
    if (!(lastSeen > 0) || !(now >= lastSeen))
        return "offline"
    const days = Math.floor((now - lastSeen) / 86400000)
    return days < 1 ? "visto hoje" : days === 1 ? "visto ontem" : `visto há ${days} dias`
}

// The hidden form of an address: its kind only, never a part of it
function tsMask(ip) {
    return typeof ip === "string" && ip.includes(":") ? "fd7a:•••" : "100.•••.•••.•••"
}
