import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"

// Configurações → Apps padrão → Iniciar com o sistema: the ArtCraft Launcher
// (hidden, a fixed command) and up to 16 apps that open when you log in
// (state/AppsState writes the list of ids; hypr/modules/autostart.lua opens
// them at login only, never on a reload). Apps that run in a terminal, are
// hidden or are not applications are not offered.
ColumnLayout {
    id: root

    readonly property bool locked: LockState.locked || LockState.wanted
    readonly property var chosen: SettingsStore.get("autostartApps") || []
    readonly property var offer: AppsState.startable.filter(a => !chosen.includes(a.id))
                                                    .map(a => ({ value: a.id, label: a.name }))

    spacing: 0

    OptionRow {
        label: "ArtCraft Launcher (escondido)"
        desc: "Abre sem janela; aparece pelo menu de apps"
        Toggle {
            checked: SettingsStore.get("autostartArtcraft") !== false
            enabled: !root.locked
            opacity: enabled ? 1 : 0.5
            onToggled: v => SettingsStore.set("autostartArtcraft", v)
        }
    }

    Repeater {
        model: root.chosen
        OptionRow {
            id: line
            required property string modelData
            readonly property var app: AppsState.find(modelData)
            divider: true
            label: app ? app.name : modelData
            desc: app ? "" : "Não está mais instalado: não abre"
            Button {
                text: "Tirar"
                enabled: !root.locked
                onClicked: AppsState.removeStart(line.modelData)
            }
        }
    }

    OptionRow {
        divider: true
        label: "Adicionar"
        desc: root.chosen.length >= 16 ? "No máximo 16 apps" : "Abre quando você entra na sessão"
        Dropdown {
            options: root.offer
            value: ""
            rows: 8
            enabled: !root.locked && root.chosen.length < 16 && root.offer.length > 0
            opacity: enabled ? 1 : 0.5
            onPicked: v => AppsState.addStart(v)
        }
    }
}
