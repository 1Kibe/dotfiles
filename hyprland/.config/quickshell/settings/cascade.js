.pragma library

// When each item of a cascade starts, in ms before the speed (Theme.dur
// scales them): coming in from the top, one after another; leaving from the
// bottom up. `t` holds the Theme tokens: { start, stagger, outStagger }.

function inDelay(index, t) {
    return t.start + index * t.stagger
}

function outDelay(index, count, t) {
    return (count - 1 - index) * t.outStagger
}
