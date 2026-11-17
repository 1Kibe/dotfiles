import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"

// Configurações → Dispositivos → Impressoras (state/PrintersState): each
// printer with its state and how it is reached, its jobs, and the actions
// the state allows (Tornar padrão and Página de teste only on a queue that
// is not one announced on the network; Cancelar only on the user's own
// job). The state reads CUPS only while this card shows. Network discovery
// changes only on a click of its switch. Names, titles and the rest that
// come from outside are only ever a row's label (escaped, never markup).
ColumnLayout {
    id: root

    readonly property bool locked: LockState.locked || LockState.wanted
    property string message: ""

    spacing: 0

    onVisibleChanged: PrintersState.active = visible
    Component.onCompleted: PrintersState.active = visible
    Component.onDestruction: PrintersState.active = false
    Connections {
        target: PrintersState
        function onNotice(text) { root.message = text }
    }

    function stateText(p) {
        const st = p.state === "idle" ? "Pronta" : p.state === "printing" ? "Imprimindo"
                 : p.state === "stopped" ? "Parada" : "Estado desconhecido"
        const how = p.medium === "usb" ? "USB" : p.medium === "rede" ? "Rede" : "Outra conexão"
        return `${st} · ${how}` + (p.name === PrintersState.defaultPrinter ? " · padrão" : "")
                + (p.announced ? " · da rede: adicione pelo endereço para usar aqui" : "")
    }

    // No CUPS, or no printer yet
    Text {
        visible: PrintersState.status !== "" && PrintersState.printers.length === 0
        Layout.fillWidth: true
        Layout.margins: 8
        text: PrintersState.status === "none" ? "O serviço de impressão não respondeu ou não há impressoras"
                                              : "Nenhuma impressora adicionada"
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    Repeater {
        model: PrintersState.printers

        ColumnLayout {
            id: printer
            required property var modelData
            required property int index
            readonly property var jobs: PrintersState.jobs.filter(j => j.printer === modelData.name)
            Layout.fillWidth: true
            spacing: 0

            OptionRow {
                divider: printer.index > 0
                icon: printer.modelData.medium === "usb" ? "\u{f0553}" : "\u{f042a}"
                label: printer.modelData.name
                desc: root.stateText(printer.modelData)
                RowLayout {
                    spacing: 6
                    visible: !printer.modelData.announced
                    Button {
                        text: "Tornar padrão"
                        visible: printer.modelData.name !== PrintersState.defaultPrinter
                        enabled: !root.locked
                        onClicked: PrintersState.setDefault(printer.modelData.name)
                    }
                    Button {
                        text: "Página de teste"
                        enabled: !root.locked
                        onClicked: PrintersState.testPage(printer.modelData.name)
                    }
                }
            }
            Repeater {
                model: printer.jobs
                OptionRow {
                    id: job
                    required property var modelData
                    icon: "\u{f0219}"
                    label: modelData.title !== "" ? modelData.title : "Documento sem nome"
                    desc: modelData.mine ? "Na fila · seu" : "Na fila · de outra pessoa"
                    Button {
                        text: "Cancelar"
                        visible: job.modelData.mine
                        enabled: !root.locked
                        onClicked: PrintersState.cancel(job.modelData.id)
                    }
                }
            }
        }
    }

    OptionRow {
        divider: PrintersState.printers.length > 0
        label: "Adicionar impressora"
        desc: "Abre o assistente de impressoras (pode pedir a senha)"
        Button {
            text: "Adicionar"
            icon: "\u{f0415}"
            enabled: !root.locked
            onClicked: PrintersState.addPrinter()
        }
    }

    OptionRow {
        divider: true
        label: "Procurar impressoras na rede · sem anunciar este computador"
        desc: "Nomes .local podem ser imitados em rede compartilhada; prefira adicionar pelo endereço (IP ou ipps://)"
        Toggle {
            checked: PrintersState.discovery
            enabled: !root.locked && !PrintersState.discoveryBusy
            opacity: enabled ? 1 : 0.5
            onToggled: v => PrintersState.setDiscovery(v)
        }
    }

    Text {
        visible: root.message !== ""
        Layout.fillWidth: true
        Layout.margins: 8
        text: root.message
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }
}
