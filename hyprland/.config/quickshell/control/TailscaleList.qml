import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The control center's Tailscale section (Tailnet reads it): the switch
// (it opens the terminal to connect or disconnect), "Este aparelho" with
// its address and "Copiar", "Aparelhos" (online first, "N de M online",
// when the offline ones were last seen), "Saída para a internet" (shown
// only: the exit node in use and the ones that offer it), and "Esconder
// nomes e endereços", which masks the text on screen ("aparelho N", the
// address's kind) while "Copiar" still copies the real address; it is not
// kept, every opening shows them. Names from outside show as plain text.
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

    component Caption: Text {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 6
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.gray
        font.family: Theme.font
        font.pointSize: Theme.fontSize - 1
    }
    component Ring: Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: Theme.radius
        color: Theme.clear
        border.width: Theme.focusWidth
        border.color: Theme.focusRing
    }

    Layout.fillWidth: true
    spacing: 2

    // Header: the switch
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        implicitHeight: 34

        Text {
            Layout.fillWidth: true
            text: "Tailscale"
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize
            font.bold: true
        }
        PanelSwitch {
            visible: root.installed
            checked: root.running
            onToggled: root.toggleSwitch()
            Ring {
                visible: root.keyOn("switch")
            }
        }
    }

    // Why there is nothing to show (fixed words only); the switch opens the
    // terminal, where sudo asks for the password
    Caption {
        visible: text !== ""
        text: root.backend === "" ? "Lendo…"
            : root.backend === "off" ? "Tailscale desligado: o serviço tailscaled não responde"
            : root.backend === "timeout" ? "Não deu para ler o Tailscale"
            : root.backend === "NeedsLogin" ? "Entre pelo terminal: a chave abre o login"
            : root.backend === "NeedsMachineAuth" ? "Aguardando aprovação na sua conta Tailscale"
            : root.backend === "Stopped" ? "Desconectado. A chave conecta pelo terminal (pede a senha)"
            : root.backend === "Starting" ? "Conectando…"
            : root.backend === "unknown" || root.backend === "NoState" ? "Estado do Tailscale desconhecido" : ""
    }

    // ── This device ──
    ColumnLayout {
        visible: root.running && root.self !== null
        Layout.fillWidth: true
        spacing: 2

        Caption {
            text: "Este aparelho"
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 8
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: (root.hide ? "este aparelho" : root.self ? root.self.name : "") + (root.selfIp !== "" ? "   " + root.shownIp(root.selfIp) : "")
                textFormat: Text.PlainText
                maximumLineCount: 1
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pointSize: Theme.fontSize - 1
            }
            BarItem {
                visible: root.selfIp !== ""
                text: root.copied === "ok" ? "Copiado" : root.copied === "fail" ? "Não deu para copiar" : "Copiar"
                textColor: root.copied === "fail" ? Theme.red : Theme.text
                keyFocus: root.keyOn("copy")
                tooltip: "Copia o endereço de verdade"
                onClicked: root.copy()
            }
        }
    }

    // ── The peers ──
    Caption {
        visible: root.running && root.peers.length > 0
        text: `Aparelhos · ${root.onlineCount} de ${root.peers.length} online`
    }
    Flickable {
        id: flick
        visible: root.running && root.peers.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(peerColumn.implicitHeight, root.maxListHeight)
        contentWidth: width
        contentHeight: peerColumn.implicitHeight
        interactive: peerColumn.implicitHeight > root.maxListHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: peerColumn
            width: flick.width
            spacing: 2

            Repeater {
                model: root.peers

                RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    spacing: 6

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: modelData.online ? Theme.green : Theme.gray
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.shownName(modelData, index) + (modelData.ips.length > 0 ? "   " + root.shownIp(modelData.ips[0]) : "")
                        textFormat: Text.PlainText
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }
                    Text {
                        text: Lists.tsSeen(modelData.online, modelData.lastSeen, Date.now())
                        textFormat: Text.PlainText
                        color: Theme.gray
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }

    // ── The exit node: shown, never changed from here ──
    Caption {
        visible: root.running && (Tailnet.exits.length > 0 || Tailnet.exitNode !== null)
        text: "Saída para a internet"
    }
    Caption {
        visible: root.running && (Tailnet.exits.length > 0 || Tailnet.exitNode !== null)
        Layout.topMargin: 0
        color: Tailnet.exitNode !== null ? Theme.yellow : Theme.gray
        text: Tailnet.exitNode !== null
              ? "Em uso: o tráfego sai por " + root.shownName(Tailnet.exitNode, root.peers.indexOf(Tailnet.exitNode))
              : `Nenhuma em uso · ${Tailnet.exits.length} ${Tailnet.exits.length === 1 ? "aparelho oferece" : "aparelhos oferecem"}`
    }

    // ── Hide names and addresses (screen privacy; not kept) ──
    RowLayout {
        visible: root.running
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.topMargin: 6
        implicitHeight: 30

        Text {
            Layout.fillWidth: true
            text: "Esconder nomes e endereços"
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
        PanelSwitch {
            checked: root.hide
            onToggled: root.hide = !root.hide
            Ring {
                visible: root.keyOn("hide")
            }
        }
    }
}
