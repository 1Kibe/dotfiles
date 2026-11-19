import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.state
import qs.bar
import "lists.js" as Lists

// The control center's Tailscale section (Tailnet reads it): the header
// with the state and the switch (it opens the terminal to connect or
// disconnect); each group in a block of its own: "Este aparelho" with its
// address and a copy icon, "Aparelhos" ("N de M online"; online ones with
// their address, offline ones dim with when they were last seen and no
// address; a name gives way, an address never); "Saída para a internet"
// (shown only: the exit node in use, or "Nenhuma"); and "Esconder nomes e
// endereços", which masks the text on screen ("aparelho N", the address's
// kind) while the copy still copies the real address; it is not kept,
// every opening shows them. Names from outside show as plain text.
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
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Layout.topMargin: 4
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
    spacing: 4

    // Header: the icon, "Tailscale", the state (dim) and the switch
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        implicitHeight: 34
        spacing: 8

        Text {
            text: String.fromCodePoint(0xF0582)   // nf-md-vpn, as the grid's button
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize
        }
        Text {
            Layout.fillWidth: true
            text: "Tailscale"
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
            font.weight: Font.Medium
        }
        Text {
            visible: text !== ""
            text: Tailnet.summary
            textFormat: Text.PlainText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSizeSmall
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

    // ── This device: a dot, "Este aparelho", the address, the copy icon ──
    // Its own block: card fill, rounded corners
    Rectangle {
        visible: root.running && root.self !== null
        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.radius
        color: Theme.bg

        Item {
            anchors.fill: parent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 4
                spacing: 8

                Rectangle {
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: Theme.green
                }
                Text {
                    Layout.fillWidth: true
                    text: "Este aparelho"
                    textFormat: Text.PlainText
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize - 1
                }
                Text {
                    visible: root.selfIp !== ""
                    text: root.shownIp(root.selfIp)
                    textFormat: Text.PlainText
                    color: Theme.fg4
                    font.family: Theme.monoFont
                    font.pointSize: Theme.fontSizeSmall
                }
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
    }

    // ── The peers ──
    // The group's header: its name left, the count right, dim
    RowLayout {
        visible: root.running && root.peers.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Layout.topMargin: 6

        Text {
            Layout.fillWidth: true
            text: "Aparelhos"
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
            font.weight: Font.Medium
        }
        Text {
            text: `${root.onlineCount} de ${root.peers.length} online`
            textFormat: Text.PlainText
            color: Theme.gray
            font.family: Theme.font
            font.pointSize: Theme.fontSizeSmall
        }
    }
    Rectangle {
        visible: root.running && root.peers.length > 0
        Layout.fillWidth: true
        implicitHeight: flick.implicitHeight
        radius: Theme.radius
        color: Theme.bg

        Flickable {
            id: flick
            width: parent.width
            implicitHeight: Math.min(peerColumn.implicitHeight, root.maxListHeight)
            contentWidth: width
            contentHeight: peerColumn.implicitHeight
            interactive: peerColumn.implicitHeight > root.maxListHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: peerColumn
                width: flick.width
                spacing: 0

                Repeater {
                    model: root.peers

                    // Online: the dot, the name, the address. Offline: the
                    // whole row dim, and when it was last seen instead of
                    // the address. The name gives way, the address never.
                    Item {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 30

                        // A thin line between the rows
                        Rectangle {
                            visible: index > 0
                            width: parent.width
                            height: 1
                            color: Theme.bg1
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                implicitWidth: 7
                                implicitHeight: 7
                                radius: 3.5
                                color: modelData.online ? Theme.green : Theme.bg2
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.shownName(modelData, index)
                                textFormat: Text.PlainText
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                color: modelData.online ? Theme.fg : Theme.gray
                                font.family: Theme.font
                                font.pointSize: Theme.fontSize - 1
                            }
                            Text {
                                text: modelData.online ? (modelData.ips.length > 0 ? root.shownIp(modelData.ips[0]) : "")
                                                       : Lists.tsSeen(false, modelData.lastSeen, Date.now())
                                textFormat: Text.PlainText
                                color: modelData.online ? Theme.fg4 : Theme.gray
                                font.family: modelData.online ? Theme.monoFont : Theme.font
                                font.pointSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }

    // ── The exit node: one line, the value in a light pill; shown only,
    // never chosen from here ──
    RowLayout {
        visible: root.running
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 6
        Layout.topMargin: 6
        implicitHeight: 30
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "Saída para a internet"
            textFormat: Text.PlainText
            color: Theme.fg
            font.family: Theme.font
            font.pointSize: Theme.fontSize - 1
        }
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

    // ── Hide names and addresses (screen privacy; not kept) ──
    RowLayout {
        visible: root.running
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 6
        Layout.topMargin: 4
        implicitHeight: 30

        Text {
            Layout.fillWidth: true
            text: "Esconder nomes e endereços"
            textFormat: Text.PlainText
            color: Theme.fg
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
