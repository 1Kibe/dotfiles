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
    const kept = (Array.isArray(list) ? list : []).filter(n => n && trim(n.name) !== ""
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
    const all = (Array.isArray(devices) ? devices : []).filter(d => d)
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
