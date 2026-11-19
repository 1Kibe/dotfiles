.pragma library

// The control center's sliders: volume and brightness. Plain JS: read by the
// shell and by the tests.

// A volume step (the wheel, ←/→): 5% per step, 0..1, whole percents; never
// raised past 100% (a value above it, set by another app, stays)
function stepVolume(v, steps) {
    const now = Number(v) || 0
    if (steps > 0 && now >= 1)
        return now
    const next = Math.min(1, Math.max(0, now + 0.05 * steps))
    return Math.round(next * 100) / 100
}

// The only brightness that goes to brightnessctl: a whole percent from 1 to
// 100 (0 would leave the screen black; anything else is refused)
function validPercent(n) {
    return typeof n === "number" && Number.isInteger(n) && n >= 1 && n <= 100
}

// The keys write with "-e4" (actions.lua); the slider does the same, so a
// percent means the same brightness either way. brightnessctl -m reports the
// raw value and the maximum: the percent on that curve is (raw/max)^(1/4)
var EXPONENT = 4
function curvePercent(raw, max) {
    if (!(max > 0) || !(raw >= 0))
        return 0
    return Math.round(Math.pow(Math.min(1, raw / max), 1 / EXPONENT) * 100)
}

// One line of `brightnessctl -m`: "device,class,current,percent,max" →
// { current, max }, or null when it is not that
function parseMachine(text) {
    const line = String(text || "").split("\n")[0].trim()
    const f = line.split(",")
    if (f.length !== 5 || f[1] !== "backlight" || !/^[0-9]{1,9}$/.test(f[2]) || !/^[0-9]{1,9}$/.test(f[4]))
        return null
    const max = parseInt(f[4], 10)
    return max > 0 ? { current: parseInt(f[2], 10), max: max } : null
}
