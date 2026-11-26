.pragma library

// The color seal of the profile cards (a corner cut square with four bands):
// its polygons in 0-100 coordinates, exactly as the spec draws them, and the
// two named colors of its last bands, by a pure rule. Plain JS: read by
// settings/ui/ColorSeal.qml and the tests.

// The outline (the darkest tone, also the color of the gaps between the
// bands) and the four bands; the fourth already cut by the outline
var POLYGONS = {
    outline: "M0 0 H100 V72 L74 100 H0 Z",
    band1: "M0 0 H9 V100 H0 Z",
    band2: "M12 0 H61 V55 L16 100 H12 Z",
    band3: "M64 0 H86 V55 L41 100 H19 L64 55 Z",
    band4: "M89 0 H100 V72 L74 100 H44 L89 55 Z"
}
// The same polygons as points (for the tests)
var POINTS = {
    outline: [[0, 0], [100, 0], [100, 72], [74, 100], [0, 100]],
    band1: [[0, 0], [9, 0], [9, 100], [0, 100]],
    band2: [[12, 0], [61, 0], [61, 55], [16, 100], [12, 100]],
    band3: [[64, 0], [86, 0], [86, 55], [41, 100], [19, 100], [64, 55]],
    band4: [[89, 0], [100, 0], [100, 72], [74, 100], [44, 100], [89, 55]]
}
// The named colors, in the order that breaks ties
var ORDER = ["yellow", "orange", "red", "green", "aqua", "blue", "purple"]

// A "#rrggbb"'s hue, 0 to 360 (a gray: 0)
function hue(hex) {
    const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.substr(i, 2), 16) / 255)
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
    if (d === 0)
        return 0
    let h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4
    h *= 60
    return h < 0 ? h + 360 : h
}
// The distance between two hues around the circle, 0 to 180
function hueDistance(a, b) {
    const d = Math.abs(a - b) % 360
    return d > 180 ? 360 - d : d
}

// The two named colors of the seal's last bands: of the seven, the one
// whose hue is nearest the accent goes out, and of the six left the two
// whose hues are farthest apart; ties by ORDER. [nameA, nameB], in ORDER
function sealColors(named, accentHex) {
    const a = hue(accentHex)
    let nearest = ORDER[0], best = Infinity
    for (const n of ORDER) {
        const d = hueDistance(hue(named[n]), a)
        if (d < best) {
            best = d
            nearest = n
        }
    }
    const left = ORDER.filter(n => n !== nearest)
    let pair = [left[0], left[1]], far = -1
    for (let i = 0; i < left.length; i++) {
        for (let j = i + 1; j < left.length; j++) {
            const d = hueDistance(hue(named[left[i]]), hue(named[left[j]]))
            if (d > far) {
                far = d
                pair = [left[i], left[j]]
            }
        }
    }
    return pair
}
