.pragma library
// Window cards for the overview: rows, each card keeps its window's aspect
// ratio, never grows past the real size, never overlaps another card and
// never leaves the area horizontally. Too many windows: rows keep a minimum
// height and the result is taller than the area (the middle scrolls).

function order(a, b) {
    if (a.y !== b.y) return a.y - b.y
    if (a.x !== b.x) return a.x - b.x
    return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0)
}

function ratio(win) { return win.w / win.h }

// Splits the list into `count` rows of almost the same size, in order
function evenRows(list, count) {
    var per = Math.ceil(list.length / count), rows = []
    for (var i = 0; i < list.length; i += per) rows.push(list.slice(i, i + per))
    return rows
}

// Height every row could have for these rows to fit the area
function fitHeight(rows, area, gap) {
    var h = (area.h - gap * (rows.length - 1)) / rows.length
    for (var r = 0; r < rows.length; r++) {
        var sum = 0
        for (var i = 0; i < rows[r].length; i++) sum += ratio(rows[r][i])
        h = Math.min(h, (area.w - gap * (rows[r].length - 1)) / sum)
    }
    return h
}

// Rows filled greedily at height h, each one within the area's width
function greedyRows(list, area, gap, h) {
    var rows = [], row = [], width = 0
    for (var i = 0; i < list.length; i++) {
        var w = ratio(list[i]) * h
        if (row.length > 0 && width + gap + w > area.w) { rows.push(row); row = []; width = 0 }
        width += (row.length > 0 ? gap : 0) + w
        row.push(list[i])
    }
    if (row.length > 0) rows.push(row)
    return rows
}

function arrange(wins, area, gap, minH) {
    var list = wins.filter(function (v) { return v.w > 0 && v.h > 0 }).slice().sort(order)
    if (list.length === 0 || area.w <= 0 || area.h <= 0) return { cards: [], height: 0 }

    var bestRows = null, bestH = -1
    for (var n = 1; n <= list.length; n++) {
        var rows = evenRows(list, n), h = fitHeight(rows, area, gap)
        if (h > bestH) { bestH = h; bestRows = rows }
    }
    var rowH = bestH
    if (rowH < minH) { rowH = minH; bestRows = greedyRows(list, area, gap, minH) }

    var placed = [], total = 0
    for (var r = 0; r < bestRows.length; r++) {
        var row = bestRows[r], sum = 0
        for (var i = 0; i < row.length; i++) sum += ratio(row[i])
        // A single very wide window may still need to shrink to fit the width
        var h = Math.min(rowH, (area.w - gap * (row.length - 1)) / sum)
        var cards = [], width = 0, tallest = 0
        for (var j = 0; j < row.length; j++) {
            var ch = Math.min(h, row[j].h), cw = ch * ratio(row[j])
            cards.push({ id: row[j].id, w: cw, h: ch })
            width += (j > 0 ? gap : 0) + cw
            tallest = Math.max(tallest, ch)
        }
        placed.push({ cards: cards, width: width, height: tallest })
        total += (r > 0 ? gap : 0) + tallest
    }

    var y = area.y + (total < area.h ? (area.h - total) / 2 : 0), out = []
    for (var k = 0; k < placed.length; k++) {
        var x = area.x + (area.w - placed[k].width) / 2
        for (var m = 0; m < placed[k].cards.length; m++) {
            var c = placed[k].cards[m]
            out.push({ id: c.id, x: Math.round(x), y: Math.round(y + (placed[k].height - c.h) / 2),
                       w: Math.round(c.w), h: Math.round(c.h) })
            x += c.w + gap
        }
        y += placed[k].height + gap
    }
    return { cards: out, height: Math.round(total) }
}
