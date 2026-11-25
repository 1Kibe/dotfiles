.pragma library

// The notice in the middle of the screen (state/OsdState): plain JS, read
// by the shell and by the tests. A device's state is one string, "<id>
// <volume> <muted>" (the microphone: "<id> <muted>").

// A number in 0..1 (anything else: 0)
function clamp(v) {
    return typeof v === "number" && isFinite(v) ? Math.max(0, Math.min(1, v)) : 0
}

// { id, volume, muted } of a state string, null for none
function parse(state) {
    if (typeof state !== "string" || state === "")
        return null
    const p = state.split(" ")
    if (p.length === 2)
        return { id: p[0], volume: p[1] === "true" ? 0 : 1, muted: p[1] === "true" }
    if (p.length !== 3)
        return null
    return { id: p[0], volume: clamp(Number(p[1])), muted: p[2] === "true" }
}

// Whether going from before to now is a change to show: the same device,
// another value. The first reading (nothing before), a device that comes
// or goes, and another device only move the base
function isChange(before, now) {
    const a = parse(before)
    const b = parse(now)
    return a !== null && b !== null && a.id === b.id && before !== now
}

// The icon (Nerd Font) by kind, level and mute: volume by thirds, the
// microphone on or off, brightness low, medium or high
function icon(kind, level, muted) {
    if (kind === "mic")
        return muted ? String.fromCodePoint(0xF036D) : String.fromCodePoint(0xF036C)
    if (kind === "brightness")
        return level < 0.34 ? String.fromCodePoint(0xF00DE) : level < 0.67 ? String.fromCodePoint(0xF00DF) : String.fromCodePoint(0xF00E0)
    if (muted || level <= 0)
        return String.fromCodePoint(0xF075F)
    return level < 0.34 ? String.fromCodePoint(0xF057F) : level < 0.67 ? String.fromCodePoint(0xF0580) : String.fromCodePoint(0xF057E)
}
