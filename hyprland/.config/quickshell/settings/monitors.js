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
        if (!s.mode || !isInt(s.mode.w) || !isInt(s.mode.h) || typeof s.mode.r !== "number"
                || !list.some(m => sameMode(m, s.mode)))
            return fail(`Tela ${s.name}: resolução que ela não oferece`)
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
            fields = `output = ${lua(s.name)}, disabled = false, mode = ${lua(`${s.mode.w}x${s.mode.h}@${s.mode.r}`)}, `
                     + `position = ${lua(`${s.x}x${s.y}`)}, scale = ${lua(s.scale)}, transform = ${lua(s.transform)}`
        text += `hl.monitor({ ${fields} })\n`
    }
    return { ok: true, text: text }
}
