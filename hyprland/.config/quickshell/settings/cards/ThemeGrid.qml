import QtQuick
import qs.theme
import qs.state
import "../ui"
import "../../theme/palettes.js" as Palettes

// Configurações → Temas: one miniature per theme of the catalog, each in the
// flavor chosen now (or its first one when it has not that one) and the
// accent chosen now. A click picks the theme in one change (SettingsStore
// setMany): the flavor kept when the theme has it, else the theme's first.
// Nothing changes with the screen locked.
Item {
    id: root

    implicitHeight: grid.implicitHeight

    readonly property string theme: SettingsStore.values.theme ?? ""
    readonly property string flavor: SettingsStore.values.flavor ?? ""
    readonly property string accent: SettingsStore.values.accent ?? "padrao"
    // The flavor a theme shows in: the chosen one if it has it, else its first
    function flavorOf(t) {
        return Object.prototype.hasOwnProperty.call(t.sabores, flavor) ? flavor : Palettes.flavors(t)[0].id
    }
    function pick(t) {
        if (LockState.locked || LockState.wanted || t.id === theme)
            return
        SettingsStore.setMany({ theme: t.id, flavor: flavorOf(t) })
    }

    Flow {
        id: grid
        width: parent.width
        spacing: 12
        Repeater {
            model: ThemeCatalog.themes
            ThemeThumb {
                required property var modelData
                width: Math.max(120, Math.floor((grid.width - 2 * grid.spacing) / 3))
                colors: Palettes.resolve(modelData, root.flavorOf(modelData), root.accent)
                name: modelData.nome
                chosen: modelData.id === root.theme
                onPicked: root.pick(modelData)
            }
        }
    }
}
