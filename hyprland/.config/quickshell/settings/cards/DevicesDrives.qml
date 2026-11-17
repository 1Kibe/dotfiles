import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import "../ui"

// Configurações → Dispositivos → Pendrives e HDs (state/DrivesState, the
// one place that mounts): each removable drive with its size, free space
// and the actions its state allows (Abrir and Ejetar when mounted, Montar
// when not). A filesystem that is not mounted on its own says so, and so
// does a drive plugged in while the screen was locked. "Montar sozinho ao
// conectar" is the autoMount setting; turning it on mounts nothing that is
// already plugged in. A label from the drive is only ever a row's label.
ColumnLayout {
    id: root

    readonly property bool locked: LockState.locked || LockState.wanted
    property string message: ""

    spacing: 0

    onVisibleChanged: if (visible) DrivesState.refresh()
    Connections {
        target: DrivesState
        function onNotice(text) { root.message = text }
    }

    function size(bytes) {
        if (typeof bytes !== "number" || !isFinite(bytes) || bytes <= 0)
            return ""
        const units = ["B", "KB", "MB", "GB", "TB"]
        let v = bytes
        let u = 0
        while (v >= 1000 && u < units.length - 1) {
            v /= 1000
            u++
        }
        return `${v >= 100 || u === 0 ? Math.round(v) : v.toFixed(1).replace(".", ",")} ${units[u]}`
    }
    function name(d) {
        if (d.label !== "")
            return d.label
        return typeof d.size === "number" && d.size >= 256e9 ? "HD externo" : "Pendrive"
    }
    function details(d) {
        const parts = [size(d.size), d.fstype.toUpperCase()]
        if (d.state === "mounting")
            parts.push("montando…")
        else if (d.state === "ejecting")
            parts.push("ejetando…")
        else if (d.mounted)
            parts.push(d.avail !== null ? `montado · ${size(d.avail)} livres` : "montado")
        else
            parts.push("não montado")
        if (!d.auto)
            parts.push("tipo complexo, só de fonte confiável")
        if (d.lockedPlug)
            parts.push("plugado com a tela bloqueada")
        return parts.filter(p => p !== "").join(" · ")
    }

    Text {
        visible: DrivesState.drives.length === 0
        Layout.fillWidth: true
        Layout.margins: 8
        text: "Nenhum pendrive, HD externo ou cartão conectado"
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    Repeater {
        model: DrivesState.drives
        OptionRow {
            id: drive
            required property var modelData
            required property int index
            divider: index > 0
            icon: "\u{f02ca}"
            label: root.name(modelData)
            desc: root.details(modelData)
            RowLayout {
                spacing: 6
                Button {
                    text: "Abrir"
                    visible: drive.modelData.mounted && drive.modelData.mountpoint !== ""
                    enabled: !root.locked && drive.modelData.state === "mounted"
                    onClicked: DrivesState.open(drive.modelData.token)
                }
                Button {
                    text: "Ejetar"
                    visible: drive.modelData.mounted
                    enabled: !root.locked && drive.modelData.state === "mounted"
                    onClicked: DrivesState.eject(drive.modelData.token)
                }
                Button {
                    text: "Montar"
                    visible: !drive.modelData.mounted
                    enabled: !root.locked && drive.modelData.state === "free"
                    onClicked: DrivesState.mount(drive.modelData.token)
                }
            }
        }
    }

    OptionRow {
        divider: true
        label: "Montar sozinho ao conectar"
        desc: "Só FAT32 e exFAT, com a sessão destravada; o que for plugado com a tela bloqueada espera o botão Montar"
        Toggle {
            checked: SettingsStore.ready && SettingsStore.get("autoMount") !== false
            enabled: !root.locked && SettingsStore.ready
            opacity: enabled ? 1 : 0.5
            onToggled: v => SettingsStore.set("autoMount", v)
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
