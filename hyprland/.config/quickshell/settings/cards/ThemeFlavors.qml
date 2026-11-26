import QtQuick
import qs.theme
import qs.state
import "../ui"
import "../../theme/palettes.js" as Palettes

// Configurações → Temas → Sabor: the chosen theme's flavors, by the names its
// palette gives them (plain text), in the four fixed places' order. A theme
// with one flavor shows it alone. A stored theme or flavor the catalog no
// longer has shows as the one the shell applies (the repo's default theme,
// the theme's first flavor).
Item {
    id: root

    implicitHeight: seg.implicitHeight

    readonly property var theme: ThemeCatalog.get(SettingsStore.values.theme ?? "")
                                 ?? ThemeCatalog.get(SettingsStore.defaults.theme ?? "")
    readonly property var options: theme ? Palettes.flavors(theme).map(f => ({ value: f.id, label: f.rotulo })) : []
    readonly property string flavor: options.some(o => o.value === SettingsStore.values.flavor) ? SettingsStore.values.flavor
                                     : options.length > 0 ? options[0].value : ""

    Segmented {
        id: seg
        options: root.options
        value: root.flavor
        onPicked: v => {
            if (!LockState.locked && !LockState.wanted)
                SettingsStore.set("flavor", v)
        }
    }
}
