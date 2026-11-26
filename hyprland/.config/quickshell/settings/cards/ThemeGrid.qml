import QtQuick
import qs.theme
import qs.state
import "../ui"
import "../../theme/palettes.js" as Palettes

// Configurações → Temas: one miniature per theme of the catalog, each in the
// flavor chosen now (or its first one when it has not that one) and the
// accent chosen now. A click picks the theme in one change (SettingsStore
// setMany): the flavor kept when the theme has it, else the theme's first.
// With the keyboard focus (Tab), the arrows move the choice like the
// accent's dots (up and down by a row). Nothing changes with the screen
// locked. A stored theme the catalog no longer has shows as the repo's
// default, the one the shell applies.
Item {
    id: root

    activeFocusOnTab: true

    readonly property var effective: ThemeCatalog.get(SettingsStore.values.theme ?? "")
                                     ?? ThemeCatalog.get(SettingsStore.defaults.theme ?? "")
    readonly property string theme: effective ? effective.id : ""
    readonly property string flavor: SettingsStore.values.flavor ?? ""
    readonly property string accent: SettingsStore.values.accent ?? "padrao"
    // The flavor a theme shows in: the chosen one if it has it, else its first
    function flavorOf(t) {
        return Object.prototype.hasOwnProperty.call(t.sabores, flavor) ? flavor : Palettes.flavors(t)[0].id
    }
    function pick(t) {
        if (LockState.locked || LockState.wanted || t.id === theme)
            return
        const change = { theme: t.id, flavor: flavorOf(t) }
        SwapState.run(() => SettingsStore.setMany(change), { fromCursor: true })
    }
    readonly property int columns: 3
    readonly property int chosenIndex: ThemeCatalog.themes.findIndex(t => t.id === theme)
    function step(by) {
        const list = ThemeCatalog.themes
        const i = chosenIndex + by
        if (chosenIndex >= 0 && i >= 0 && i < list.length)
            pick(list[i])
    }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onUpPressed: step(-columns)
    Keys.onDownPressed: step(columns)

    implicitHeight: grid.implicitHeight + newButton.height + 12 + (refusal.visible ? refusal.implicitHeight + 8 : 0)
    // A change of theme, flavor or accent refused while the monitors or the
    // keyboard are applied (state/SwapState): said here, at the top of the
    // page those three are on
    Text {
        id: refusal
        visible: SwapState.refusal !== ""
        anchors.bottom: newButton.top
        anchors.bottomMargin: 8
        width: parent.width
        wrapMode: Text.WordWrap
        text: SwapState.refusal
        textFormat: Text.PlainText
        color: Theme.yellow
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 2
    }
    Button {
        id: newButton
        anchors.bottom: parent.bottom
        icon: "󰐕"
        text: "Novo tema personalizado"
        onClicked: {
            if (!LockState.locked && !LockState.wanted) {
                ShellState.themeEditId = ""
                ShellState.themeEditing = true
            }
        }
    }
    Flow {
        id: grid
        width: parent.width
        spacing: 12
        Repeater {
            model: ThemeCatalog.themes
            ThemeThumb {
                required property var modelData
                width: Math.max(120, Math.floor((grid.width - (root.columns - 1) * grid.spacing) / root.columns))
                colors: Palettes.resolve(modelData, root.flavorOf(modelData), root.accent)
                name: modelData.nome
                own: ThemeCatalog.isOwn(modelData.id)
                onEdit: {
                    if (!LockState.locked && !LockState.wanted) {
                        ShellState.themeEditId = modelData.id
                        ShellState.themeEditing = true
                    }
                }
                chosen: modelData.id === root.theme
                focusRing: chosen && root.activeFocus
                onPicked: root.pick(modelData)
            }
        }
    }
}
