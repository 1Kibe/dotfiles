.pragma library

// The screens the bar shows on (Configurações → Monitores, "Mostrar a barra
// em"): every screen when nothing is chosen, only the chosen one when it is
// there, and every screen again when it is gone (nothing is saved for
// that). Plain JS: read by shell.qml and by the tests.
function pick(names, chosen) {
    const all = Array.isArray(names) ? names : []
    if (typeof chosen !== "string" || chosen === "" || !all.includes(chosen))
        return all
    return [chosen]
}
