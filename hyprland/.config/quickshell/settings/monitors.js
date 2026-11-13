.pragma library

// Configurações → Monitores: the screens' arrangement as Hyprland Lua
// (~/.config/hypr/dotfiles_monitors.lua, loaded by hyprland.lua before
// local.lua). Plain JS: read by the shell and by the tests.
//
// A screen is known by its port name (eDP-1, HDMI-A-1, Virtual-1): only
// names of that shape pass, and never one that Hyprland would read as a
// selector (a number, a direction, "current", "desc:..."). The monitor's
// description, maker, model and serial come from outside (EDID): they are
// only shown, cleaned first, and never written anywhere.
//
// The file is a fixed template, one hl.monitor() per screen, a screen that
// is on saying "disabled = false" (a rule that turned it off stays until
// another says so, also for a preview applied over it); only checked
// numbers, booleans and port names (through the serializer) fill it. An
// arrangement that would leave no screen on, screens on top of each other
// or apart, a mode the screen does not list, a scale that does not fit,
// or a mirror of a mirror is refused and nothing is written.

var NAME = /^[A-Za-z]+(-[A-Za-z0-9]+)*-[0-9]{1,3}$/
var SELECTORS = ["current", "next", "prev", "l", "r", "u", "d", "left", "right", "up", "down", "desc"]
var MAX_POSITION = 16384
var MIN_SCALE = 0.5
var MAX_SCALE = 4
var MIN_LOGICAL = [640, 360]
var DESCRIPTION_MAX = 64

function validName(name) {
    return typeof name === "string" && name.length <= 32 && NAME.test(name)
        && !SELECTORS.includes(name.toLowerCase())
}

// For showing only: no control or text-direction characters, at most 64
function cleanDescription(text) {
    if (typeof text !== "string")
        return ""
    const clean = text.replace(/[\u0000-\u001f\u007f-\u009f‎‏‪-‮⁦-⁩]/g, "").trim()
    return Array.from(clean).slice(0, DESCRIPTION_MAX).join("")
}

// "1920x1080@60.00Hz" (hyprctl's availableModes) → { w, h, r }, or null
function parseMode(text) {
    const m = /^([0-9]{2,5})x([0-9]{2,5})@([0-9]{1,3}(\.[0-9]{1,3})?)(Hz)?$/.exec(String(text))
    if (!m)
        return null
    return { w: parseInt(m[1], 10), h: parseInt(m[2], 10), r: parseFloat(m[3]) }
}

function sameMode(a, b) {
    return a.w === b.w && a.h === b.h && Math.abs(a.r - b.r) < 0.01
}

function isInt(v) {
    return typeof v === "number" && Number.isInteger(v)
}

// The size a screen takes in the arrangement (scaled, turned)
function logicalSize(screen) {
    const turned = screen.transform % 2 === 1
    const w = screen.mode.w / screen.scale
    const h = screen.mode.h / screen.scale
    return turned ? { w: h, h: w } : { w: w, h: h }
}

// Two boxes share area (not just an edge)
function overlap(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}
// Two boxes touch along an edge (a stretch longer than a point)
function touch(a, b) {
    const side = (a.x + a.w === b.x || b.x + b.w === a.x)
                 && Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y) > 0
    const stacked = (a.y + a.h === b.y || b.y + b.h === a.y)
                    && Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x) > 0
    return side || stacked
}

function fail(error) {
    return { ok: false, error: error }
}

// screens: [{ name, enabled, mode: { w, h, r }, x, y, scale, transform,
// mirror }]; modes: { name: [availableModes text] }; lua: the serializer's
// luaValue. → { ok: true, text } or { ok: false, error } (pt-BR)
function generate(screens, modes, lua) {
    if (!Array.isArray(screens) || screens.length === 0 || screens.length > 9)
        return fail("Nenhuma tela para arrumar")
    const byName = {}
    for (const s of screens) {
        if (!s || !validName(s.name))
            return fail("Nome de tela inválido")
        if (byName[s.name])
            return fail(`A tela ${s.name} aparece duas vezes`)
        if (typeof s.enabled !== "boolean")
            return fail(`Tela ${s.name}: ligada ou não?`)
        byName[s.name] = s
    }
    const boxes = []
    // The mode written is the screen's own (from its list), never the
    // number asked for
    const chosen = {}
    for (const s of screens) {
        if (!s.enabled)
            continue
        const mirror = s.mirror || ""
        if (mirror !== "") {
            const target = byName[mirror]
            if (mirror === s.name)
                return fail(`A tela ${s.name} não pode espelhar ela mesma`)
            if (!target || !target.enabled)
                return fail(`A tela ${s.name} espelha uma tela desligada ou que não existe`)
            if (target.mirror)
                return fail(`A tela ${s.name} espelha um espelho`)
            continue
        }
        const list = (modes && Array.isArray(modes[s.name]) ? modes[s.name] : []).map(parseMode).filter(m => m)
        const listed = s.mode && isInt(s.mode.w) && isInt(s.mode.h) && typeof s.mode.r === "number"
                       ? list.find(m => sameMode(m, s.mode)) : undefined
        if (!listed)
            return fail(`Tela ${s.name}: resolução que ela não oferece`)
        chosen[s.name] = listed
        if (!isInt(s.x) || !isInt(s.y) || Math.abs(s.x) > MAX_POSITION || Math.abs(s.y) > MAX_POSITION)
            return fail(`Tela ${s.name}: posição fora do limite`)
        if (!isInt(s.transform) || s.transform < 0 || s.transform > 7)
            return fail(`Tela ${s.name}: rotação inválida`)
        if (typeof s.scale !== "number" || !isFinite(s.scale) || s.scale < MIN_SCALE || s.scale > MAX_SCALE
                || Math.abs(s.scale * 20 - Math.round(s.scale * 20)) > 1e-6)
            return fail(`Tela ${s.name}: escala inválida`)
        const size = logicalSize(s)
        if (Math.abs(size.w - Math.round(size.w)) > 0.01 || Math.abs(size.h - Math.round(size.h)) > 0.01)
            return fail(`Tela ${s.name}: a escala ${s.scale} não serve para ${s.mode.w}×${s.mode.h}`)
        if (Math.max(size.w, size.h) < MIN_LOGICAL[0] || Math.min(size.w, size.h) < MIN_LOGICAL[1])
            return fail(`Tela ${s.name}: escala grande demais para essa resolução`)
        boxes.push({ name: s.name, x: s.x, y: s.y, w: Math.round(size.w), h: Math.round(size.h) })
    }
    if (boxes.length === 0)
        return fail("Pelo menos uma tela precisa ficar ligada")
    for (let i = 0; i < boxes.length; i++)
        for (let j = i + 1; j < boxes.length; j++)
            if (overlap(boxes[i], boxes[j]))
                return fail(`As telas ${boxes[i].name} e ${boxes[j].name} ficam uma em cima da outra`)
    // All joined: from the first, every screen reached through touching edges
    const reached = [boxes[0]]
    for (let k = 0; k < reached.length; k++)
        for (const b of boxes)
            if (!reached.includes(b) && touch(reached[k], b))
                reached.push(b)
    if (reached.length !== boxes.length)
        return fail("As telas precisam ficar encostadas, sem espaço entre elas")

    let text = "-- Generated by the shell (Configurações → Monitores): rewritten by the page.\n"
    for (const s of screens) {
        let fields
        if (!s.enabled)
            fields = `output = ${lua(s.name)}, disabled = true`
        else if (s.mirror)
            fields = `output = ${lua(s.name)}, disabled = false, mode = "preferred", position = "auto", scale = "auto", `
                     + `mirror = ${lua(s.mirror)}`
        else
            fields = `output = ${lua(s.name)}, disabled = false, `
                     + `mode = ${lua(`${chosen[s.name].w}x${chosen[s.name].h}@${chosen[s.name].r}`)}, `
                     + `position = ${lua(`${s.x}x${s.y}`)}, scale = ${lua(s.scale)}, transform = ${lua(s.transform)}`
        text += `hl.monitor({ ${fields} })\n`
    }
    return { ok: true, text: text }
}

// The screens as Hyprland has them (hyprctl -j monitors all, the turned-off
// ones too), at most 9, only port names (never its FALLBACK), the
// description cleaned for showing: [{ name, description, enabled, mode
// (from the screen's list, or null), x, y, scale, transform, mirror, modes
// (its list, as text) }]
function fromHyprctl(list) {
    const out = []
    if (!Array.isArray(list))
        return out
    for (const m of list) {
        if (out.length >= 9)
            break
        if (!m || !validName(m.name) || out.some(s => s.name === m.name))
            continue
        const modes = Array.isArray(m.availableModes) ? m.availableModes.filter(t => parseMode(t) !== null) : []
        const now = { w: m.width, h: m.height, r: typeof m.refreshRate === "number" ? m.refreshRate : 0 }
        const listed = modes.map(parseMode).find(x => sameMode(x, now))
        const mirror = typeof m.mirrorOf === "string" && validName(m.mirrorOf) ? m.mirrorOf : ""
        out.push({
            name: m.name,
            description: cleanDescription(m.description),
            enabled: m.disabled !== true,
            mode: listed || null,
            x: isInt(m.x) ? m.x : 0,
            y: isInt(m.y) ? m.y : 0,
            scale: typeof m.scale === "number" && isFinite(m.scale) ? m.scale : 1,
            transform: isInt(m.transform) ? m.transform : 0,
            mirror: mirror,
            modes: modes
        })
    }
    return out
}

// { name: [modes] } for generate()
function modesOf(screens) {
    const out = {}
    for (const s of Array.isArray(screens) ? screens : [])
        out[s.name] = s.modes
    return out
}

// The scales generate() takes for this mode (0,5 to 4, every 0,05, whole
// logical pixels, at least 640×360)
function scalesFor(mode) {
    const out = []
    if (!mode || !isInt(mode.w) || !isInt(mode.h))
        return out
    for (let i = MIN_SCALE * 20; i <= MAX_SCALE * 20; i++) {
        const scale = i / 20
        const w = mode.w / scale
        const h = mode.h / scale
        if (Math.abs(w - Math.round(w)) > 0.01 || Math.abs(h - Math.round(h)) > 0.01)
            continue
        if (Math.max(w, h) < MIN_LOGICAL[0] || Math.min(w, h) < MIN_LOGICAL[1])
            continue
        out.push(scale)
    }
    return out
}

// ── For the page (settings/cards/MonitorLayout, MonitorDetails) ──

// A screen's place in the arrangement (scaled, turned): { x, y, w, h }
function box(screen) {
    const size = logicalSize(screen)
    return { x: screen.x, y: screen.y, w: Math.round(size.w), h: Math.round(size.h) }
}

// The screen's resolutions, biggest first: [{ value: "1920x1080", label }]
function resolutions(modes) {
    const seen = {}
    const out = []
    for (const m of (Array.isArray(modes) ? modes : []).map(parseMode).filter(x => x)) {
        const key = `${m.w}x${m.h}`
        if (seen[key])
            continue
        seen[key] = true
        out.push({ value: key, label: `${m.w} × ${m.h}`, area: m.w * m.h })
    }
    out.sort((a, b) => b.area - a.area)
    return out.map(o => ({ value: o.value, label: o.label }))
}

// The rates of one resolution, fastest first: [{ value: r, label: "60 Hz" }]
function rates(modes, w, h) {
    const out = []
    for (const m of (Array.isArray(modes) ? modes : []).map(parseMode).filter(x => x))
        if (m.w === w && m.h === h && !out.some(o => Math.abs(o.value - m.r) < 0.01))
            out.push({ value: m.r, label: `${String(Math.round(m.r * 100) / 100).replace(".", ",")} Hz` })
    out.sort((a, b) => b.value - a.value)
    return out
}

// Where a screen being dragged lands: touching another one along an edge
// (a stretch longer than a point), never on top of any; lined up with its
// edges or center when close (`near`, in arrangement pixels); the spot
// nearest to where it was dropped. `boxes`: every screen on (not mirrors);
// `i`: the one moving. → { x, y } (whole numbers)
function snap(boxes, i, x, y, near) {
    const me = boxes[i]
    const others = boxes.filter((b, k) => k !== i)
    if (others.length === 0)
        return { x: 0, y: 0 }
    const pull = typeof near === "number" ? near : 40
    const free = (cx, cy) => !others.some(o => overlap({ x: cx, y: cy, w: me.w, h: me.h }, o))
    // Along an edge of o: the lined-up spots, else the dropped one kept on it
    const along = (start, length, pos, mySize) => {
        const lined = [start, start + length - mySize, start + (length - mySize) / 2]
        const best = lined.reduce((a, b) => Math.abs(b - pos) < Math.abs(a - pos) ? b : a)
        if (Math.abs(best - pos) <= pull)
            return Math.round(best)
        return Math.round(Math.max(start - mySize + 1, Math.min(start + length - 1, pos)))
    }
    const spots = []
    for (const o of others) {
        const cy = along(o.y, o.h, y, me.h)
        const cx = along(o.x, o.w, x, me.w)
        spots.push({ x: o.x - me.w, y: cy }, { x: o.x + o.w, y: cy }, { x: cx, y: o.y - me.h }, { x: cx, y: o.y + o.h })
    }
    const good = spots.filter(s => free(s.x, s.y))
    if (good.length === 0)
        return { x: me.x, y: me.y }
    good.sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y))
    return { x: good[0].x, y: good[0].y }
}

// A screen just turned on goes to the right of the others, at the top
function placeRight(boxes) {
    let x = 0
    for (const b of boxes)
        x = Math.max(x, b.x + b.w)
    return { x: x, y: 0 }
}

// The arrangement moved so that its top-left corner is 0,0
function normalize(screens) {
    const on = screens.filter(s => s.enabled && !s.mirror && s.mode)
    if (on.length === 0)
        return screens
    const minX = Math.min(...on.map(s => s.x))
    const minY = Math.min(...on.map(s => s.y))
    return screens.map(s => s.enabled && !s.mirror ? Object.assign({}, s, { x: s.x - minX, y: s.y - minY }) : s)
}

// The page's scale list: the usual ones first (when they fit), then the
// rest from 1 up (below 1 everything gets tiny; the generator still takes it)
var USUAL_SCALES = [1, 1.25, 1.5, 1.6, 2]
function scaleChoices(mode) {
    const all = scalesFor(mode).filter(s => s >= 1)
    const first = USUAL_SCALES.filter(s => all.includes(s))
    return first.concat(all.filter(s => !first.includes(s)))
        .map(s => ({ value: s, label: String(s).replace(".", ",") }))
}
