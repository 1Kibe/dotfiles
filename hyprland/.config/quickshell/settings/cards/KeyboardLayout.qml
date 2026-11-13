import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"
import "../keyboard.js" as Keyboard

// Configurações → Teclado e mouse → Layout (state/KeyboardLayout): the
// system's own list of layouts. Picking one tries it in Hyprland for 15 s
// ("Manter este teclado?"); kept, it is saved and then set for the login,
// which asks the administrator's password in the system's own window. The
// card says when the login still has another layout (with a button to set
// it), when local.lua sets the layout, and when the saved one is not in the
// list. The test field is only for typing: its text is never saved, logged
// or sent anywhere, it is cleared when the card goes away or the session
// locks, and it is off while locked.
ColumnLayout {
    id: root

    readonly property bool locked: LockState.locked || LockState.wanted
    readonly property string saved: String(SettingsStore.get("kbLayout"))
    readonly property bool savedUsable: SystemLists.has("layouts", saved)
    readonly property string shown: KeyboardLayout.pending ? KeyboardLayout.tried : savedUsable ? saved : ""
    readonly property var system: KeyboardLayout.system

    spacing: 0
    Component.onCompleted: KeyboardLayout.readSystem()
    onLockedChanged: if (locked) test.input.text = ""
    onVisibleChanged: if (!visible) test.input.text = ""

    OptionRow {
        label: "Layout"
        desc: "Vale por 15 s até você manter. Para o teclado do login, o sistema pede a senha de administrador"
        Dropdown {
            options: Keyboard.options(SystemLists.layouts)
            value: root.shown
            rows: 10
            enabled: !root.locked && !KeyboardLayout.busy && !KeyboardLayout.settingLogin
                     && SystemLists.layoutsRead && SystemLists.layouts.length > 0
            opacity: enabled ? 1 : 0.5
            onPicked: v => {
                if (v !== root.shown)
                    KeyboardLayout.preview(v)
            }
        }
    }

    // What the card has to say, one line each
    component Notice: RowLayout {
        id: notice
        property string icon: "󰋼"
        property color tone: Theme.fg4
        property string text: ""
        default property alias extra: tail.data
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        spacing: 10
        Text {
            Layout.alignment: Qt.AlignTop
            text: notice.icon
            color: notice.tone
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        Text {
            Layout.fillWidth: true
            text: notice.text
            textFormat: Text.PlainText
            color: Theme.text
            wrapMode: Text.WordWrap
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
        RowLayout {
            id: tail
        }
    }

    Notice {
        visible: !SystemLists.layoutsRead
        text: "Lendo os layouts do sistema…"
    }
    Notice {
        visible: SystemLists.layoutsRead && SystemLists.layouts.length === 0
        icon: "󰀦"
        tone: Theme.yellow
        text: "Não achei a lista de layouts do sistema: o layout não muda por aqui"
    }
    Notice {
        visible: SystemLists.layoutsRead && SystemLists.layouts.length > 0 && !root.savedUsable
        icon: "󰀦"
        tone: Theme.yellow
        text: "O layout guardado não está na lista do sistema e não foi aplicado"
    }
    Notice {
        visible: KeyboardLayout.systemRead && root.savedUsable && !KeyboardLayout.pending
                 && !KeyboardLayout.settingLogin && root.system.layout !== root.saved
        icon: "󰌌"
        tone: Theme.yellow
        text: root.system.layout !== "" ? `O teclado do login continua com ${Keyboard.label(root.system.layout)}`
                                        : "O teclado do login usa outro layout"
        Button {
            text: "Usar também no login"
            enabled: !root.locked && !KeyboardLayout.busy
            onClicked: KeyboardLayout.useForLogin()
        }
    }
    Notice {
        visible: KeyboardLayout.settingLogin
        icon: "󰌾"
        text: "Esperando a senha de administrador na janela do sistema…"
    }
    Notice {
        visible: KeyboardLayout.localSetsLayout
        icon: "󰀦"
        tone: Theme.yellow
        text: "O local.lua desta máquina também define o layout e vale por cima desta página"
    }
    Notice {
        visible: KeyboardLayout.message !== ""
        icon: "󰅚"
        tone: Theme.red
        text: KeyboardLayout.message
    }

    OptionRow {
        divider: true
        label: "Testar o teclado"
        desc: "Só para digitar: nada daqui é guardado"
        Field {
            id: test
            value: ""
            placeholder: "Digite aqui"
            enabled: !root.locked
            opacity: enabled ? 1 : 0.5
        }
    }
}
