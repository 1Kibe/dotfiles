.pragma library

// The month of the clock's panel (bar/CalendarView): plain JS, read by the
// shell and by the tests. Months are 0 to 11, as in Date; firstDay is the
// week's first day (0 Sunday, as in pt-BR).

var MONTHS = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro",
              "novembro", "dezembro"]
// The days' initials from Sunday
var DAYS = ["D", "S", "T", "Q", "Q", "S", "S"]

function daysIn(year, month) {
    return new Date(year, month + 1, 0).getDate()
}

// The month moved by delta (any sign): { year, month }
function shift(year, month, delta) {
    const m = year * 12 + month + delta
    return { year: Math.floor(m / 12), month: ((m % 12) + 12) % 12 }
}

// "novembro de 2026"
function monthTitle(year, month) {
    return `${MONTHS[month]} de ${year}`
}

// The days' initials starting at firstDay
function weekDays(firstDay) {
    const out = []
    for (let i = 0; i < 7; i++)
        out.push(DAYS[(firstDay + i) % 7])
    return out
}

// Six weeks (42 days) starting on the week of the month's first day:
// { day, month, year, inMonth, isToday } each; today = { year, month, day }
function monthGrid(year, month, firstDay, today) {
    const first = new Date(year, month, 1).getDay()
    const lead = (first - firstDay + 7) % 7
    const prev = shift(year, month, -1)
    const next = shift(year, month, 1)
    const prevDays = daysIn(prev.year, prev.month)
    const days = daysIn(year, month)
    const out = []
    for (let i = 0; i < 42; i++) {
        let d, m, y
        if (i < lead) {
            d = prevDays - lead + 1 + i; m = prev.month; y = prev.year
        } else if (i < lead + days) {
            d = i - lead + 1; m = month; y = year
        } else {
            d = i - lead - days + 1; m = next.month; y = next.year
        }
        out.push({ day: d, month: m, year: y, inMonth: m === month && y === year,
                   isToday: !!today && today.year === y && today.month === m && today.day === d })
    }
    return out
}
