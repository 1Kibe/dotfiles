import QtQuick
import qs.theme
import qs.state
import "../ui"
import "../../theme/palettes.js" as Palettes

// Configurações → Temas → Sabor: the chosen theme's flavors, by the names its
// palette gives them (plain text), in the four fixed places' order. A theme
// with one flavor shows it alone.
Item {
    id: root

    implicitHeight: seg.implicitHeight

    readonly property var theme: ThemeCatalog.get(SettingsStore.values.theme ?? "")
    readonly property var options: theme ? Palettes.flavors(theme).map(f => ({ value: f.id, label: f.rotulo })) : []

    Segmented {
        id: seg
        options: root.options
        value: SettingsStore.values.flavor ?? ""
        onPicked: v => {
            if (!LockState.locked && !LockState.wanted)
                SettingsStore.set("flavor", v)
        }
    }
}
