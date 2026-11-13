.pragma library

// Configurações → Teclado e mouse, into Hyprland's input options: a fixed
// list of settings keys, each one tied to one option of Hyprland 0.57 that
// it has natively. Plain JS: read by state/SettingsApply and by the tests.
// Only the keys of this list are ever written, each value checked again
// against its schema key (whole numbers and decimals within min/max, true
// or false, an option of the list) and written through the serializer
// passed in (settings/serialize.js luaValue). A value that does not pass
// throws: the generated file is then not written and stays as it was.
// The layout is not here (it has its own card, with a preview to keep).

// [settings key, Hyprland option, kind]; touchpad options go in
// input.touchpad, the others in input
var KEYS = [
    ["repeatRate", "repeat_rate", "int"],
    ["repeatDelay", "repeat_delay", "int"],
    ["numlockOnStart", "numlock_by_default", "bool"],
    ["mouseSensitivity", "sensitivity", "real"],
    ["mouseAccel", "accel_profile", "enum"],
    ["mouseNatural", "natural_scroll", "bool"],
    ["mouseLeftHanded", "left_handed", "bool"],
    ["focusFollowsMouse", "follow_mouse", "follow"]
]
var TOUCHPAD_KEYS = [
    ["tapToClick", "tap_to_click", "bool"],
    ["tapAndDrag", "tap_and_drag", "bool"],
    ["touchpadNatural", "natural_scroll", "bool"],
    ["disableWhileTyping", "disable_while_typing", "bool"]
]

function own(obj, key) {
    return obj !== null && typeof obj === "object" && Object.prototype.hasOwnProperty.call(obj, key)
}

// One value checked against its schema key; throws when it does not pass
function checked(spec, value, kind) {
    if (!spec)
        throw new Error("input: chave fora do schema")
    switch (kind) {
    case "int":
        if (!Number.isInteger(value) || value < spec.min || value > spec.max)
            throw new Error("input: número fora do limite")
        return value
    case "real":
        if (typeof value !== "number" || !isFinite(value) || value < spec.min || value > spec.max)
            throw new Error("input: número fora do limite")
        return value
    case "bool":
        if (typeof value !== "boolean")
            throw new Error("input: valor inválido")
        return value
    case "follow":
        if (typeof value !== "boolean")
            throw new Error("input: valor inválido")
        // Hyprland's follow_mouse: 1 = the focus follows the pointer, 0 = only a click
        return value ? 1 : 0
    case "enum":
        if (!Array.isArray(spec.options) || !spec.options.some(o => o.value === value))
            throw new Error("input: opção inválida")
        return value
    default:
        throw new Error("input: tipo desconhecido")
    }
}

function lines(list, v, keys, lua, indent) {
    return list.map(([key, option, kind]) => {
        const value = checked(own(keys, key) ? keys[key] : null, own(v, key) ? v[key] : undefined, kind)
        return `${indent}${option} = ${lua(value)},`
    })
}

// The Lua block for the generated file. `v`: the settings' values; `keys`:
// settings/schema.js KEYS; `lua`: serialize.js luaValue
function inputLua(v, keys, lua) {
    return [
        "-- Teclado, mouse e touchpad (Configurações → Teclado e mouse)",
        "hl.config({",
        "  input = {",
        ...lines(KEYS, v, keys, lua, "    "),
        "    touchpad = {",
        ...lines(TOUCHPAD_KEYS, v, keys, lua, "      "),
        "    },",
        "  },",
        "})"
    ].join("\n") + "\n"
}

// Whether `hyprctl -j devices` lists a touchpad. Only the answer leaves
// this function: the devices' names are tested here and never kept,
// shown or written anywhere
function hasTouchpad(text) {
    let data = null
    try {
        data = JSON.parse(text)
    } catch (e) {
        return false
    }
    const mice = own(data, "mice") && Array.isArray(data.mice) ? data.mice : []
    return mice.some(m => own(m, "name") && typeof m.name === "string" && /touchpad|trackpad/i.test(m.name))
}
