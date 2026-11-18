.pragma library

// Keyboard moves inside the control center. groups: the focus groups in Tab
// order, each { name, count, columns } (columns 1 = a list); pos: { group,
// index }. Arrows stay inside the group (the grid in its columns, a list up
// and down, never past the ends); Tab and Shift+Tab go to the next and the
// previous group that has something, round, to its first item. A group
// that shrank keeps the position inside it; one that emptied gives the
// first group that has items. Returns a new pos. Plain JS: read by the
// shell and by the tests.
function fit(groups, pos) {
    const g = groups.find(x => x.name === pos.group)
    if (g && g.count > 0)
        return { group: g.name, index: Math.max(0, Math.min(g.count - 1, pos.index)) }
    const first = groups.find(x => x.count > 0)
    return first ? { group: first.name, index: 0 } : { group: "", index: 0 }
}

function move(groups, pos, key) {
    const p = fit(groups, pos)
    const at = groups.findIndex(x => x.name === p.group)
    if (at < 0)
        return p
    const g = groups[at]
    const cols = Math.max(1, g.columns || 1)
    let i = p.index
    if (key === "tab" || key === "backtab") {
        const step = key === "tab" ? 1 : -1
        for (let k = 1; k <= groups.length; k++) {
            const next = groups[(at + step * k + groups.length * 2) % groups.length]
            if (next.count > 0)
                return { group: next.name, index: 0 }
        }
        return p
    }
    if (key === "left" && cols > 1 && i % cols > 0)
        i -= 1
    else if (key === "right" && cols > 1 && i % cols < cols - 1 && i + 1 < g.count)
        i += 1
    else if (key === "up" && i - cols >= 0)
        i -= cols
    else if (key === "down" && i + cols < g.count)
        i += cols
    return { group: g.name, index: i }
}
