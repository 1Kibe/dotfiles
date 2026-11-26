.pragma library

// The cards on the screen and the central's list (state/NotificationState):
// plain JS, read by the shell and by the tests. An entry here is a plain
// object of cleaned text: { id, appKey, urgent, time, ... }.

// The central: at most this many, and per app
var STORE_MAX = 200
var STORE_PER_APP = 50
// Urgent ones kept in the central, at most (so they never push out every
// normal one)
var STORE_URGENT_MAX = 50
// The pace: per app and in all, in a window of PACE_MS; the apps
// remembered for it. The key is what the message says it is (anyone can
// use any name): the pace per app is a cap, never an identity, and the
// global one is shared by all of them
var PACE_PER_APP = 20
var PACE_ALL = 60
var PACE_MS = 10000
var PACE_KEYS = 256

// An app's key: its desktop entry (cleaned, exact), else its name
function appKey(desktopEntry, appName) {
    return typeof desktopEntry === "string" && desktopEntry !== "" ? desktopEntry : (typeof appName === "string" ? appName : "")
}

// A new notification over the cards on screen ([{ id, appKey, urgent,
// count }], newest first). One of the same app (not urgent, nor the new one
// urgent) takes its place: it shows the newest and counts "N novas" (a
// replacement of the same id does not count). An urgent one never joins
// the normal ones; it takes the place of an urgent one of the same app.
// Else it goes on top. → { list, merged }
function mergeOnScreen(list, n) {
    if (n.urgent) {
        const rest = list.filter(c => !(c.urgent && c.appKey === n.appKey && n.appKey !== ""))
        return { list: [Object.assign({ count: 1 }, n)].concat(rest), merged: rest.length !== list.length }
    }
    {
        const i = list.findIndex(c => !c.urgent && c.appKey === n.appKey && n.appKey !== "")
        if (i >= 0) {
            const old = list[i]
            const card = Object.assign({}, n, { count: old.id === n.id ? old.count : old.count + 1 })
            const rest = list.filter((_, k) => k !== i)
            return { list: [card].concat(rest), merged: true }
        }
    }
    return { list: [Object.assign({ count: 1 }, n)].concat(list), merged: false }
}

// At most max cards (newest first); an urgent one takes the place of the
// oldest normal one. The rest wait in the central: they never come back
// to the screen. → { shown, more }
function limitScreen(list, max) {
    if (list.length <= max)
        return { shown: list, more: 0 }
    let shown = list.slice()
    while (shown.length > max) {
        // The oldest normal card goes first; only urgent ones: the oldest
        let k = -1
        for (let i = shown.length - 1; i >= 0; i--) {
            if (!shown[i].urgent) {
                k = i
                break
            }
        }
        shown.splice(k >= 0 ? k : shown.length - 1, 1)
    }
    return { shown: shown, more: list.length - max }
}

// The central over its caps: the oldest goes first, a normal one before an
// urgent one; urgent ones have a cap of their own (STORE_URGENT_MAX); the
// per-app cap, then the total. keepId (the one just in) is never the one
// taken out. → { store, removed } (removed: the ids taken out)
function trim(store, maxTotal, maxPerApp, keepId) {
    let s = store.slice()
    const removed = []
    // The oldest of the indexes in list (not keepId), a normal one first
    // unless onlyUrgent
    const drop = (list, onlyUrgent) => {
        let k = -1
        let oldest = Infinity
        for (const urgentPass of onlyUrgent ? [true] : [false, true]) {
            for (let i = 0; i < list.length; i++) {
                const e = s[list[i]]
                if (e.id !== keepId && !!e.urgent === urgentPass && e.time < oldest) {
                    oldest = e.time
                    k = list[i]
                }
            }
            if (k >= 0)
                break
        }
        if (k < 0)
            return false
        removed.push(s[k].id)
        s.splice(k, 1)
        return true
    }
    const all = () => s.map((_, i) => i)
    while (s.filter(e => e.urgent).length > STORE_URGENT_MAX) {
        if (!drop(all(), true))
            break
    }
    // (a Map: an app's name is never a key of a plain object, where
    // "constructor" or "__proto__" are already taken)
    const counts = new Map()
    for (const e of s)
        counts.set(e.appKey, (counts.get(e.appKey) || 0) + 1)
    for (const [key, n] of counts) {
        let left = n
        while (left > maxPerApp) {
            const idx = []
            s.forEach((e, i) => { if (e.appKey === key) idx.push(i) })
            if (!drop(idx, false))
                break
            left--
        }
    }
    while (s.length > maxTotal) {
        if (!drop(all(), false))
            break
    }
    return { store: s, removed: removed }
}

// The pace: { history: { key: [times] }, all: [times] } (a new object back).
// → { ok, pace } where ok is false when the app or all of them are over;
// at most PACE_KEYS apps remembered (the least recent forgotten)
// (history: a Map by app, so an app named "constructor" or "__proto__" is
// one more key, never a property of a plain object)
function pace(state, key, now) {
    const st = state && state.history instanceof Map ? state : { history: new Map(), all: [] }
    const since = now - PACE_MS
    const all = st.all.filter(t => t > since)
    const mine = (st.history.get(key) || []).filter(t => t > since)
    if (all.length >= PACE_ALL || mine.length >= PACE_PER_APP)
        return { ok: false, pace: { history: st.history, all: all } }
    const keys = Array.from(st.history.keys()).filter(k => k !== key)
        .map(k => ({ k: k, t: st.history.get(k).filter(t => t > since) }))
        .filter(x => x.t.length > 0)
        .sort((a, b) => b.t[b.t.length - 1] - a.t[a.t.length - 1])
        .slice(0, PACE_KEYS - 1)
    const history = new Map()
    for (const x of keys)
        history.set(x.k, x.t)
    history.set(key, mine.concat([now]))
    return { ok: true, pace: { history: history, all: all.concat([now]) } }
}
