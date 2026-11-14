import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"

// Configurações → Sobre → Versão: the repo's branch, commit, date and tag
// (state/AboutState asks git four fixed questions), the GitHub link (a fixed
// address in the code), and the system: distro, kernel, Hyprland,
// Quickshell, processor and memory. Never the machine's or the user's name,
// a serial, an address or what is not committed. Everything as plain text;
// "—" when a value could not be read.
ColumnLayout {
    id: root

    spacing: 0
    Component.onCompleted: AboutState.refresh()

    component Value: Text {
        textFormat: Text.PlainText
        elide: Text.ElideRight
        maximumLineCount: 1
        horizontalAlignment: Text.AlignRight
        Layout.maximumWidth: 260
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    OptionRow {
        label: "Branch"
        desc: AboutState.checked && !AboutState.repoOk ? "Repo não encontrado, ou com dono ou permissão errados" : ""
        Value { text: AboutState.branch }
    }
    OptionRow {
        divider: true
        label: "Commit"
        Value { text: AboutState.commit }
    }
    OptionRow {
        divider: true
        label: "Data"
        Value { text: AboutState.date }
    }
    OptionRow {
        divider: true
        label: "Versão (tag)"
        Value { text: AboutState.tag }
    }
    OptionRow {
        divider: true
        label: "GitHub"
        desc: "github.com/1Kibe/dotfiles"
        Button {
            text: "Abrir"
            icon: "󰊤"
            onClicked: AboutState.openGithub()
        }
    }

    Text {
        Layout.topMargin: 14
        Layout.leftMargin: 8
        text: "Sistema"
        textFormat: Text.PlainText
        color: Theme.accentLight
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
        font.weight: Font.DemiBold
    }
    OptionRow {
        label: "Distribuição"
        Value { text: AboutState.distro }
    }
    OptionRow {
        divider: true
        label: "Kernel"
        Value { text: AboutState.kernel }
    }
    OptionRow {
        divider: true
        label: "Hyprland"
        Value { text: AboutState.hyprland }
    }
    OptionRow {
        divider: true
        label: "Quickshell"
        Value { text: AboutState.quickshell }
    }
    OptionRow {
        divider: true
        label: "Processador"
        Value { text: AboutState.cpu }
    }
    OptionRow {
        divider: true
        label: "Memória"
        Value { text: AboutState.memory }
    }
}
