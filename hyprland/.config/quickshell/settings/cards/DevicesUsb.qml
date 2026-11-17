import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.state
import "../ui"
import "../devices.js" as Devices

// Configurações → Dispositivos → Conectados por USB: only the names of what
// is plugged in, read while this card shows (settings/devices.js usbList:
// hubs on one line, a storage device that also acts as a keyboard marked).
// The reading is a fixed sh over /sys/bus/usb/devices: per device only its
// class, its interfaces' classes, manufacturer and product, 256 bytes each
// at most, with every control character removed (a name can add neither a
// field nor a line); never the serial number nor the vendor and product
// ids. The last line says where the other devices are set.
ColumnLayout {
    id: root

    property var list: ({ devices: [], hubs: 0, unread: 0, truncated: 0 })
    property bool read: false

    spacing: 0

    function refresh() {
        if (scan.running)
            return
        scan.running = true
        limit.restart()
    }
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: if (visible) refresh()
    Timer {
        interval: 10000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    readonly property string script: 'r() { [ -f "$1" ] && head -c 256 -- "$1" 2>/dev/null | tr -d "\\000-\\037\\177"; }\n'
        + 'n=0 m=0\n'
        + 'for d in /sys/bus/usb/devices/*; do\n'
        + '  case "${d##*/}" in *:*) continue ;; esac\n'
        + '  [ -d "$d" ] || continue\n'
        + '  n=$((n + 1)); if [ "$n" -gt 200 ]; then m=$((m + 1)); continue; fi\n'
        + '  ifs=""\n'
        + '  for i in "$d"/*:*/bInterfaceClass; do [ -f "$i" ] && ifs="$ifs$(r "$i"),"; done\n'
        + '  printf "%s\\t%s\\t%s\\t%s\\n" "$(r "$d/bDeviceClass")" "$ifs" "$(r "$d/manufacturer")" "$(r "$d/product")"\n'
        + 'done\n'
        // The ones left out, as a line of their own (counted by usbList)
        + '[ "$m" -gt 0 ] && printf "+\\t%s\\t\\t\\n" "$m"\n'
        + 'exit 0'
    Process {
        id: scan
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = Devices.usbList(text)
                root.read = true
            }
        }
        onExited: limit.stop()
    }
    // Five seconds at most
    Timer {
        id: limit
        interval: 5000
        onTriggered: scan.running = false
    }

    Repeater {
        model: root.list.devices
        OptionRow {
            required property var modelData
            required property int index
            divider: index > 0
            icon: modelData.storage ? "\u{f02ca}" : modelData.hid ? "\u{f030c}" : "\u{f0553}"
            label: modelData.name
            desc: modelData.alsoKeyboard ? "Também age como teclado: desconecte se não esperava isso" : ""
        }
    }

    Text {
        readonly property var parts: [
            root.list.hubs > 0 ? (root.list.hubs === 1 ? "1 hub USB" : `${root.list.hubs} hubs USB`) : "",
            root.list.truncated > 0 ? `e mais ${root.list.truncated}` : "",
            root.list.unread > 0 ? `${root.list.unread} não lido(s)` : "",
            root.read && root.list.devices.length === 0 ? "Nenhum dispositivo USB além dos hubs" : ""
        ].filter(p => p !== "")
        visible: parts.length > 0
        Layout.fillWidth: true
        Layout.margins: 8
        text: parts.join(" · ")
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Theme.fg4
        font.family: Theme.fontPanels
        font.pointSize: Theme.fontSize - 1
    }

    // Where the other devices are set (wraps at the panel's width)
    Flow {
        Layout.fillWidth: true
        Layout.margins: 8
        spacing: 14
        Text {
            text: "Em outros lugares:"
            textFormat: Text.PlainText
            color: Theme.fg4
            font.family: Theme.fontPanels
            font.pointSize: Theme.fontSize - 1
        }
        Repeater {
            model: [{ label: "Monitores", page: "monitores" }, { label: "Teclado e mouse", page: "teclado" },
                    { label: "Bluetooth (abre o painel da barra)", panel: "bluetooth" },
                    { label: "Som (abre o painel da barra)", panel: "volume" }]
            Text {
                id: link
                required property var modelData
                text: modelData.label
                textFormat: Text.PlainText
                color: linkMouse.containsMouse ? Theme.accentLight : Theme.fg4
                font.family: Theme.fontPanels
                font.pointSize: Theme.fontSize - 1
                font.underline: linkMouse.containsMouse
                Behavior on color {
                    ColorAnimation { duration: Theme.dur(Theme.animFast) }
                }
                MouseArea {
                    id: linkMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (link.modelData.page) {
                            ShellState.settingsPage = ""
                            ShellState.settingsPage = link.modelData.page
                        } else {
                            ShellState.toggle(link.modelData.panel, ShellState.settingsOn)
                        }
                    }
                }
            }
        }
    }
}
