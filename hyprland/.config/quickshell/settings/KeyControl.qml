import QtQuick
import qs.state
import "ui"
import "schema.js" as Schema
import "format.js" as Format

// The control of one key (SchemaPage, KeyRow), by its type in
// settings/schema.js. It only sends the change to SettingsStore; a value
// the store refuses snaps back by binding.
Loader {
    id: ctl

    property string key
    readonly property var spec: Schema.KEYS[key]
    readonly property var value: SettingsStore.ready ? SettingsStore.values[key] : spec.def

    // A list of this machine: its names, the stored one first if it is
    // not there (the list not read yet, or a font that is gone)
    readonly property var choices: {
        if (!spec.source)
            return spec.options
        // A name never empty ("" is the emptyLabel's choice)
        const names = SystemLists.list(spec.source).filter(n => n !== "")
        const out = names.map(n => ({ value: n, label: n }))
        if (typeof value === "string" && !names.includes(value) && !(value === "" && spec.emptyLabel))
            out.unshift({ value: value, label: value })
        // "" as a choice of its own (the wallpaper on every screen)
        if (spec.emptyLabel)
            out.unshift({ value: "", label: spec.emptyLabel })
        return out
    }

    sourceComponent: spec.source ? dropdownC
                     : spec.control === "swatches" ? swatchesC
                     : spec.type === "bool" ? toggleC
                     : spec.type === "enum" ? (spec.options.length <= 4 ? segmentedC : dropdownC)
                     : spec.type === "int" || spec.type === "real" ? sliderC
                     : spec.type === "list" ? listC
                     : fieldC

    Component {
        id: toggleC
        Toggle {
            checked: ctl.value === true
            onToggled: v => SettingsStore.set(ctl.key, v)
        }
    }
    Component {
        id: swatchesC
        ColorSwatches {
            options: ctl.spec.options
            value: ctl.value
            onPicked: v => SettingsStore.set(ctl.key, v)
        }
    }
    Component {
        id: segmentedC
        Segmented {
            options: ctl.spec.options
            value: ctl.value
            onPicked: v => SettingsStore.set(ctl.key, v)
        }
    }
    Component {
        id: dropdownC
        Dropdown {
            options: ctl.choices
            value: ctl.value
            onPicked: v => SettingsStore.set(ctl.key, v)
        }
    }
    Component {
        id: listC
        Dropdown {
            multiple: true
            options: ctl.spec.options
            value: ctl.value
            onPicked: v => SettingsStore.set(ctl.key, v)
        }
    }
    Component {
        id: sliderC
        Slider {
            from: ctl.spec.min
            to: ctl.spec.max
            step: ctl.spec.step || 1
            value: ctl.value
            valueText: Format.value(ctl.spec, ctl.value)
            onMoved: v => SettingsStore.set(ctl.key, v)
        }
    }
    Component {
        id: fieldC
        Field {
            value: String(ctl.value)
            mono: ctl.spec.type === "path" || ctl.spec.preview === "fileName"
            onAccepted: text => invalid = !SettingsStore.set(ctl.key, text)
        }
    }
}
