.pragma library

// The grid of the control center: its buttons in order, two columns (Rede,
// Bluetooth / Tailscale, Atualizações / Luz noturna, then the ones that come
// with other modules). hasList: the button folds out its section (its id is
// one of ShellState.controlSections); without a list it only switches on
// and off. available false: reserved, never drawn; flag: drawn only while
// that flag is on (Não perturbe, once the notifications exist). Plain JS:
// read by the shell and by the tests.
var SECTIONS = [
    { id: "wifi", icon: String.fromCodePoint(0xF0928), label: "Rede", hasList: true },
    { id: "bluetooth", icon: String.fromCodePoint(0xF00AF), label: "Bluetooth", hasList: true },
    { id: "tailscale", icon: String.fromCodePoint(0xF0582), label: "Tailscale", hasList: true },
    { id: "updates", icon: String.fromCodePoint(0xF06B0), label: "Atualizações", hasList: true },
    { id: "nightlight", icon: String.fromCodePoint(0xF0594), label: "Luz noturna", hasList: false },
    { id: "dnd", icon: String.fromCodePoint(0xF009B), label: "Não perturbe", hasList: false, flag: "dndAvailable" },
    { id: "github", icon: String.fromCodePoint(0xF02A4), label: "GitHub", hasList: true }
]

// The buttons drawn, in order, with no gap where one is left out
function visible(sections, flags) {
    const f = flags || {}
    return sections.filter(s => s.available !== false && (!s.flag || f[s.flag] === true))
}

// Luz noturna's button: the switch (the schedule on or off) and, under it,
// the hours, with "agora" while the light is on
function nightText(enabled, start, end, active) {
    const hours = start && end ? `${start}–${end}` : ""
    return {
        status: enabled ? "Ligada" : "Desligada",
        hours: enabled && active ? `${hours} · agora` : hours
    }
}
