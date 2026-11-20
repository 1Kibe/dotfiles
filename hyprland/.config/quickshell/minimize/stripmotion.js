.pragma library

// The minimized strip's levels: "hidden" (no window), "wire" (5 px with
// dots), "icons", "names". Plain JS: the QML only starts the timers and
// animates. step(level, event, n) -> { level, timer: { name, ms } | null,
// cancel: [names] }. Events: "filled" (the first window came), "empty" (the
// last one left), "enter" / "leave" (the mouse), "timer150" (still on the
// edge: open in icons), "timer300" (out for a while: back to the wire),
// "hold" (still on the open strip: names), "flash" (a window just came:
// icons for a moment), "flashEnd".
var OPEN_MS = 150
var CLOSE_MS = 300

function step(level, event) {
    const none = { level: level, timer: null, cancel: [] }
    if (event === "empty")
        return { level: "hidden", timer: null, cancel: ["open", "close", "hold", "flash", "room"] }
    if (event === "filled")
        return level === "hidden" ? { level: "wire", timer: null, cancel: [] } : none
    if (level === "hidden")
        return none
    if (event === "enter")
        return level === "wire" ? { level: "wire", timer: { name: "open", ms: OPEN_MS }, cancel: ["close", "flash"] }
                                : { level: level, timer: null, cancel: ["close", "flash"] }
    if (event === "leave")
        return level === "wire" ? { level: "wire", timer: null, cancel: ["open", "hold", "room"] }
                                : { level: level, timer: { name: "close", ms: CLOSE_MS }, cancel: ["open", "hold", "room", "flash"] }
    if (event === "timer150")
        return level === "wire" ? { level: "icons", timer: null, cancel: [] } : none
    if (event === "hold")
        return level === "icons" ? { level: "names", timer: null, cancel: [] } : none
    if (event === "timer300")
        return { level: "wire", timer: null, cancel: ["hold"] }
    // A window minimized: open in icons a moment; another one while it is
    // open from a flash makes the moment longer
    if (event === "flash")
        return level === "wire" || level === "icons" ? { level: "icons", timer: { name: "flash", ms: 0 }, cancel: [] } : none
    if (event === "flashEnd")
        return level === "icons" ? { level: "wire", timer: null, cancel: [] } : none
    return none
}
