.pragma library

// How a setting's value reads on the page (settings/SchemaPage, the
// "Alterado · padrão …" line): always with its unit. Plain JS: read by the
// shell and by the tests.
//
// spec.format "percent": a 0–1 value as a whole percent (0.85 → "85%").
// spec.unit: written after the number ("8 px", "100 itens"; "%" and "°"
// stick to it). Real numbers use a decimal comma. Enums show their option's
// label, lists their labels, booleans "Ligado"/"Desligado".

function number(v, step) {
    // As many decimals as the step has (0.05 → 2), never more than 2
    const s = String(step === undefined ? 1 : step)
    const places = s.includes(".") ? Math.min(2, s.length - s.indexOf(".") - 1) : 0
    return (places > 0 ? v.toFixed(places) : String(Math.round(v))).replace(".", ",")
}

function withUnit(text, unit) {
    if (!unit)
        return text
    return unit === "%" || unit === "°" ? text + unit : text + " " + unit
}

function label(spec, v) {
    const o = (spec.options || []).find(x => x.value === v)
    return o ? o.label : String(v)
}

function value(spec, v) {
    if (!spec)
        return String(v)
    switch (spec.type) {
    case "bool":
        return v === true ? "Ligado" : "Desligado"
    case "enum":
        return label(spec, v)
    case "list":
        return Array.isArray(v) && v.length > 0 ? v.map(x => label(spec, x)).join(", ") : "Nenhum"
    case "int":
    case "real":
        if (typeof v !== "number" || !isFinite(v))
            return String(v)
        if (spec.format === "percent")
            return Math.round(v * 100) + "%"
        return withUnit(number(v, spec.type === "int" ? 1 : spec.step), spec.unit)
    default:
        if (v === "" && spec.emptyLabel)
            return spec.emptyLabel
        return String(v)
    }
}
