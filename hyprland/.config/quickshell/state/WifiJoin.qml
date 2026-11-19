pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../control/lists.js" as Lists

// Joining a Wi-Fi network, for the Wi-Fi list (control/NetworkList) of the
// control center and of the bar's network panel. One attempt at a time
// (a second click or Enter while one runs does nothing).
//   A saved network connects with what NetworkManager keeps (connect()); only
//   when that fails for lack of secrets (NoSecrets) does its password field
//   open. Typing a password on a saved network would overwrite the one kept
//   before knowing it failed.
//   A new secured network opens its password field; the password goes to
//   NetworkManager (connectWithPsk, over D-Bus, never as an argument). A new
//   network that fails or gives up is forgotten: NetworkManager saves the
//   profile at the attempt, and the next click would retry the wrong
//   password without asking. A network saved before is never forgotten.
//   An open network joins after a confirmation; once connected its profile
//   is set to never join by itself (anyone can make another network with the
//   same name). Only an open network's profile is written: an update made
//   from here goes without the secrets and would drop a saved password.
//   20 s without an answer: it gives up and disconnects.
//   Messages are fixed: "Senha incorreta" only for NoSecrets after a typed
//   password, "Não deu para conectar" for anything else; never a name.
//   A hidden network goes through nmcli (the API has none): the profile is
//   added with the name as an argument (never the password), its UUID
//   checked, brought up with --ask and the password written on the process's
//   input, 25 s at most; a failure brings the Wi-Fi down and deletes that
//   profile, and only that one. Its failure is always "Não deu para conectar".
Singleton {
    id: root

    // The network being joined (null with none, or the hidden one)
    property var target: null
    property bool busy: false
    property bool wasKnown: false
    property bool withPassword: false
    // The network whose password field is open, the open network waiting for
    // its confirmation, and the last message with the network it is about
    // ("" none; "<oculta>" the hidden network form)
    property string asking: ""
    property string confirming: ""
    property string error: ""
    property string errorFor: ""
    property int timeoutMs: 20000   // 20 s (a test shortens it)

    function isOpen(net) {
        return net !== null && net !== undefined && net.security === WifiSecurityType.Open
    }

    // The list closed (or the center, or the screen locked): the fields,
    // the confirmation and the message go away. An attempt already running
    // goes on.
    function reset() {
        asking = ""
        confirming = ""
        error = ""
        errorFor = ""
    }

    // A click (or Enter) on a network that is not connected
    function choose(net) {
        if (!net || busy)
            return
        error = ""
        errorFor = ""
        if (net.known) {
            begin(net, "")
        } else if (isOpen(net)) {
            asking = ""
            confirming = confirming === net.name ? "" : net.name
        } else {
            confirming = ""
            asking = asking === net.name ? "" : net.name
        }
    }
    // "Conectar" under an open network's warning
    function confirmOpen(net) {
        if (!net || busy || !isOpen(net) || confirming !== net.name)
            return
        begin(net, "")
    }
    // The password typed under a network's row: read once, here; the caller
    // wipes its field right after. False when refused (busy, not a valid
    // password); nothing is kept.
    function submit(net, psk) {
        if (!net || busy || isOpen(net) || !Lists.validPsk(psk))
            return false
        begin(net, psk)
        return true
    }

    function begin(net, psk) {
        target = net
        busy = true
        wasKnown = net.known === true
        withPassword = psk !== ""
        asking = ""
        confirming = ""
        error = ""
        errorFor = ""
        deadline.interval = timeoutMs
        deadline.restart()
        if (withPassword)
            net.connectWithPsk(psk)
        else
            net.connect()
    }
    // Ends the attempt; returns its network
    function finish(message) {
        deadline.stop()
        const net = target
        busy = false
        target = null
        if (message !== "") {
            error = message
            errorFor = net ? net.name : ""
        }
        return net
    }

    Connections {
        target: root.target
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            root.failed(reason)
        }
        function onConnectedChanged() {
            if (root.target && root.target.connected)
                root.joined()
        }
    }

    // A signal with no attempt running (a late or repeated one) does nothing
    function failed(reason) {
        if (!target)
            return
        const known = wasKnown
        const typed = withPassword
        let net
        if (reason === ConnectionFailReason.NoSecrets && !typed) {
            // A saved network whose kept password no longer works: ask for it
            net = finish("")
            if (net)
                asking = net.name
        } else if (reason === ConnectionFailReason.NoSecrets) {
            net = finish("Senha incorreta")
            if (net)
                asking = net.name
        } else {
            net = finish("Não deu para conectar")
        }
        if (net && !known)
            net.forget()
    }

    function joined() {
        if (!target)
            return
        const known = wasKnown
        const net = finish("")
        if (!net || !isOpen(net))
            return
        // Never join an open network by itself; only a profile with no
        // security part is written (see above)
        for (const s of net.nmSettings) {
            const m = s.read()
            if (m["802-11-wireless-security"] === undefined)
                s.write({ connection: { autoconnect: false } })
        }
    }

    // 20 s with no answer
    Timer {
        id: deadline
        onTriggered: {
            const known = root.wasKnown
            const net = root.finish("Não deu para conectar")
            if (net) {
                net.disconnect()
                if (!known)
                    net.forget()
            }
        }
    }

    // ── A hidden network (nmcli) ──
    readonly property string hiddenScript: [
        'IFS= read -r psk || exit 3',
        'out=$(nmcli -t connection add type wifi ifname "$2" ssid "$1" 802-11-wireless.hidden yes wifi-sec.key-mgmt wpa-psk 2>/dev/null) || exit 4',
        'uuid=$(printf "%s\\n" "$out" | grep -oE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | head -n 1)',
        'printf "%s\\n" "$uuid" | grep -qxE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" || exit 5',
        'if printf "%s\\n" "$psk" | timeout 25 nmcli --ask connection up uuid "$uuid" >/dev/null 2>&1; then exit 0; fi',
        'nmcli device disconnect "$2" >/dev/null 2>&1',
        'nmcli connection delete uuid "$uuid" >/dev/null 2>&1',
        'exit 1'
    ].join("\n")

    // name: typed by hand; iface: the Wi-Fi device's name; psk: read once.
    // "" when it started, else the message
    function joinHidden(name, iface, psk) {
        if (busy)
            return "Espere a tentativa anterior"
        const bad = Lists.hiddenCheck(name, psk)
        if (bad !== "")
            return bad
        if (typeof iface !== "string" || !/^[A-Za-z0-9_.-]{1,15}$/.test(iface))
            return "Não deu para conectar"
        busy = true
        target = null
        asking = ""
        confirming = ""
        error = ""
        errorFor = ""
        // The name and the interface as the script's arguments, through sh
        // (always there), so a missing setpriv never puts them in the log
        hidden.command = ["sh", "-c", 'exec setpriv --pdeathsig TERM -- sh -c "$1" sh "$2" "$3"', "sh",
                          hiddenScript, name, iface]
        // Held only until the process starts, then written and wiped
        hidden.input = psk + "\n"
        hidden.stdinEnabled = true
        hidden.running = true
        hiddenDeadline.restart()
        return ""
    }

    Process {
        id: hidden
        property string input: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onStarted: {
            write(input)
            input = ""
            stdinEnabled = false
        }
        onExited: code => {
            hiddenDeadline.stop()
            hidden.input = ""
            root.busy = false
            if (code !== 0) {
                root.error = "Não deu para conectar"
                root.errorFor = "<oculta>"
            }
        }
    }
    // The script gives nmcli 25 s; past 35 s the whole thing stops
    Timer {
        id: hiddenDeadline
        interval: 35000
        onTriggered: hidden.running = false
    }
}
