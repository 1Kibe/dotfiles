import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The control center's Tailscale section (Tailnet reads it): the header
// with the state and the switch (it opens the terminal to connect or
// disconnect); each group in a block of its own: this device (its name,
// "este aparelho" beside it, its address and a copy icon), "Aparelhos"
// ("N de M online"; online ones with
// their address, offline ones dim with when they were last seen and no
// address; a name gives way, an address never); "Saída para a internet"
// (shown only: the exit node in use, or "Nenhuma"); and "Esconder nomes e
// endereços", which masks the text on screen ("aparelho N", only "este
// aparelho" for this one, the address's kind) while the copy still copies
// the real address; it is not kept, every opening shows them. Names from
// outside show as plain text.
ColumnLayout {
    id: root

    // The section open
    required property bool active
    property real maxListHeight: 240
    // The item the control center's keyboard is on (-1 none)
    property int keyIndex: -1

    property bool hide: false
    // "" nothing, "ok" copied, "fail" not copied (for 2 s)
    property string copied: ""
    readonly property string backend: Tailnet.backend
    readonly property bool running: backend === "Running"
    readonly property bool installed: backend !== "off" && backend !== "" && backend !== "timeout"
    readonly property var self: Tailnet.self
    readonly property var peers: Tailnet.peers
    readonly property string selfIp: self && self.ips.length > 0 ? self.ips[0] : ""
    readonly property int onlineCount: peers.filter(p => p.online).length

    onActiveChanged: {
        hide = false
        copied = ""
        Tailnet.watch(active)
    }
    // A bar going away with the section open: the reading stops with it
    Component.onDestruction: {
        if (active)
            Tailnet.watch(false)
    }

    function shownName(p, i) {
        return hide ? `aparelho ${i + 1}` : p.name !== "" ? p.name : "sem nome"
    }
    // This device: its name with "este aparelho" beside it; hidden (or
    // with no name), only "Este aparelho"
    readonly property string selfName: !hide && self && self.name !== "" ? self.name : ""
    function shownIp(ip) {
        return ip === "" ? "" : hide ? Lists.tsMask(ip) : ip
    }
    function toggleSwitch() {
        if (!active || !installed)
            return
        if (Tailnet.openTerminal(running ? "down" : "up"))
            ShellState.close()
    }
    property bool copying: false
    function copy() {
        if (active && Tailnet.copy(selfIp))
            copying = true
    }
    Connections {
        target: Tailnet
        function onCopied(ok) {
            if (!root.copying)
                return
            root.copying = false
            root.copied = ok ? "ok" : "fail"
            copiedTimer.restart()
        }
    }
    Timer {
        id: copiedTimer
        interval: 2000
        onTriggered: root.copied = ""
    }

    // ── The control center's keyboard ──
    readonly property var keyItems: {
        const items = []
        if (installed)
            items.push({ kind: "switch" })
        if (running && selfIp !== "")
            items.push({ kind: "copy" })
        if (running)
            items.push({ kind: "hide" })
        return items
    }
    readonly property int keyCount: keyItems.length
    function keyOn(kind) {
        const it = keyItems[keyIndex]
        return it !== undefined && it.kind === kind
    }
    function pressKey(k) {
        const it = keyItems[k]
        if (!it)
            return
        if (it.kind === "switch")
            toggleSwitch()
        else if (it.kind === "copy")
            copy()
        else if (it.kind === "hide")
            hide = !hide
    }

    Layout.fillWidth: true
    spacing: 4

    ListHeader {
        section: true
        icon: String.fromCodePoint(0xF0582)   // nf-md-vpn, as the grid's button
        title: "Tailscale"
        detail: Tailnet.summary
        hasSwitch: root.installed
        checked: root.running
        switchFocus: root.keyOn("switch")
        onToggled: root.toggleSwitch()
    }

    // Why there is nothing to show (fixed words only); the switch opens the
    // terminal, where sudo asks for the password
    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        visible: text !== ""
        text: root.backend === "" ? "Lendo…"
            : root.backend === "off" ? "Tailscale desligado: o serviço tailscaled não responde"
            : root.backend === "timeout" ? "Não deu para ler o Tailscale"
            : root.backend === "NeedsLogin" ? "Entre pelo terminal: a chave abre o login"
            : root.backend === "NeedsMachineAuth" ? "Aguardando aprovação na sua conta Tailscale"
            : root.backend === "Stopped" ? "Desconectado. A chave conecta pelo terminal (pede a senha)"
            : root.backend === "Starting" ? "Conectando…"
            : root.backend === "unknown" || root.backend === "NoState" ? "Estado do Tailscale desconhecido" : ""
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }

    // ── This device: the dot, its name with "este aparelho" beside it, the
    // address, the copy icon ──
    ListBlock {
        visible: root.running && root.self !== null

        ListRow {
            dot: true
            text: root.selfName !== "" ? root.selfName : "Este aparelho"
            note: root.selfName !== "" ? "este aparelho" : ""
            detail: root.shownIp(root.selfIp)
            detailMono: true

            // The copy icon; for 2 s after a copy, how it went
            BarItem {
                visible: root.selfIp !== ""
                text: root.copied === "ok" ? "Copiado" : root.copied === "fail" ? "Não deu para copiar"
                    : String.fromCodePoint(0xF018F)   // nf-md-content_copy
                textColor: root.copied === "fail" ? Theme.red : root.copied === "ok" ? Theme.green : Theme.fg4
                fontSize: root.copied === "" ? Theme.fontSize : Theme.fontSizeSmall
                keyFocus: root.keyOn("copy")
                tooltip: root.copied === "" ? "Copiar o endereço (o de verdade)" : ""
                onClicked: root.copy()
            }
        }
    }

    // ── The peers: online ones with their address; offline ones dim, with
    // when they were last seen instead. The name gives way, the address
    // never. ──
    ListHeader {
        visible: root.running && root.peers.length > 0
        title: "Aparelhos"
        detail: `${root.onlineCount} de ${root.peers.length} online`
    }
    ListBlock {
        visible: root.running && root.peers.length > 0
        maxHeight: root.maxListHeight

        Repeater {
            model: root.peers

            ListRow {
                required property var modelData
                required property int index
                divider: index > 0
                dot: true
                dotColor: modelData.online ? Theme.green : Theme.bg2
                text: root.shownName(modelData, index)
                textColor: modelData.online ? Theme.fg : Theme.gray
                detail: modelData.online ? (modelData.ips.length > 0 ? root.shownIp(modelData.ips[0]) : "")
                                         : Lists.tsSeen(false, modelData.lastSeen, Date.now())
                detailColor: modelData.online ? Theme.fg4 : Theme.gray
                detailMono: modelData.online
            }
        }
    }

    // ── The exit node, the value in a light pill (shown only, never chosen
    // from here), and hiding names and addresses (screen privacy; not
    // kept) ──
    ListRow {
        visible: root.running
        Layout.topMargin: 4
        text: "Saída para a internet"

        Rectangle {
            Layout.maximumWidth: root.width * 0.5
            implicitWidth: exitText.implicitWidth + 16
            implicitHeight: 22
            radius: Theme.radius
            color: Theme.bg1

            Text {
                id: exitText
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                text: Tailnet.exitNode !== null ? root.shownName(Tailnet.exitNode, root.peers.indexOf(Tailnet.exitNode)) : "Nenhuma"
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                color: Tailnet.exitNode !== null ? Theme.yellow : Theme.fg2
                font.family: Theme.font
                font.pointSize: Theme.fontSizeSmall
            }
        }
    }
    ListRow {
        visible: root.running
        text: "Esconder nomes e endereços"
        clickable: true
        keyFocus: root.keyOn("hide")
        onClicked: root.hide = !root.hide

        PanelSwitch {
            checked: root.hide
            onToggled: root.hide = !root.hide
        }
    }
}
