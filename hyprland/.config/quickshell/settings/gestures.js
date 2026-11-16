.pragma library

// Configurações → Gestos, the parts with no state. The catalog is in
// settings/schema.js (keys gestures3 and gestures4: each position and the
// names it may take); a choice is only one of those names. The shell writes
// them as data (position -> name) to ~/.config/hypr/dotfiles_gestures.lua,
// and hypr/modules/keybinds.lua checks each one again against its own table
// and builds the gesture itself, so no command ever comes from the
// settings. Plain JS: read by state/SettingsApply, the Gestos page and the
// tests.
//
// 4 fingers sideways: "areas" switches areas the way the areas' mode of
// Configurações → Monitores says (one step with the areas together on every
// screen; following the fingers with each screen on its own). The page shows
// those two ways as two choices, and picking one sets the areas' mode
// (areasTogether, one key for both pages).

// The page's choices for one position of a key's spec
function choices(spec, position) {
    if (position !== "4:side")
        return spec.options.slice()
    return [{ value: "areas_follow", label: "Trocar de área (segue os dedos)" },
            { value: "areas_step", label: "Trocar de área (um passo)" },
            { value: "cycle", label: "Janela anterior / próxima" },
            { value: "none", label: "Nada" }]
}

// What the page shows for a position's saved name (together: the areas'
// mode)
function shown(position, name, together) {
    if (position === "4:side" && name === "areas")
        return together ? "areas_step" : "areas_follow"
    return name
}

// A choice of the page → { name, together } (together: undefined when the
// choice leaves the areas' mode as it is); null for one out of the list
function picked(spec, position, choice) {
    if (position === "4:side") {
        if (choice === "areas_follow")
            return { name: "areas", together: false }
        if (choice === "areas_step")
            return { name: "areas", together: true }
    }
    const names = spec.choices[position]
    return Array.isArray(names) && names.includes(choice) ? { name: choice, together: undefined } : null
}

// The text of dotfiles_gestures.lua: data only. `keys`: the schema's KEYS;
// `values`: the current ones; `validate`: validate.js validate. Each key
// checked again (a bad one: its defaults); every value through the
// serializer
function dataLua(keys, values, validate, luaValue) {
    const lines = []
    for (const key of ["gestures3", "gestures4"]) {
        const spec = keys[key]
        const r = validate(spec, values[key])
        const v = r.ok ? r.value : spec.def
        for (const p of spec.positions)
            lines.push(`  [${luaValue(p.id)}] = ${luaValue(v[p.id])},`)
    }
    return "-- Gestos do touchpad (Configurações → Gestos): read by modules/keybinds.lua\n"
           + "return {\n" + lines.join("\n") + "\n}\n"
}
