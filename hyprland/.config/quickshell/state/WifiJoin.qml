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

    // The network being joined (null with none or the hidden one). Its name
    // and, for a new network, the UUID of the profile the attempt created:
    // the network's object may go away mid attempt (out of the scan), and
    // that profile still has to go if the attempt fails.
    property var target: null
    property string targetName: ""
    property string createdUuid: ""
    property bool busy: false
    property bool wasKnown: false
    property bool withPassword: false
    // The network whose password field is open, the open network waiting for
    // its confirmation, and the last message with the network it is about
    // (objects, not names: two networks can share a name). The hidden
    // network form has its own message.
    property var askingNet: null
    property var confirmingNet: null
    property string error: ""
    property var errorNet: null
    property string hiddenError: ""
    property int timeoutMs: 20000         // 20 s (a test shortens it)
    property int hiddenTimeoutMs: 35000   // the hidden network's script, all of it

    readonly property var uuidPattern: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

    function isOpen(net) {
        return net !== null && net !== undefined && net.security === WifiSecurityType.Open
    }

    // The list closed (or the center, or the screen locked): the fields,
    // the confirmation and the messages go away. An attempt already running
    // goes on to its end (and a new network that fails is still forgotten).
    function reset() {
        askingNet = null
        confirmingNet = null
        error = ""
        errorNet = null
        hiddenError = ""
    }

    // A click (or Enter) on a network that is not connected; one row open at
    // a time
    function choose(net) {
        if (!net || busy)
            return
        error = ""
        errorNet = null
        if (net.known) {
            begin(net, "")
        } else if (isOpen(net)) {
            askingNet = null
            confirmingNet = confirmingNet === net ? null : net
        } else {
            confirmingNet = null
            askingNet = askingNet === net ? null : net
        }
    }
    // "Conectar" under an open network's warning
    function confirmOpen(net) {
        if (!net || busy || !isOpen(net) || confirmingNet !== net)
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
        targetName = net.name
        createdUuid = ""
        busy = true
        wasKnown = net.known === true
        withPassword = psk !== ""
        askingNet = null
        confirmingNet = null
        error = ""
        errorNet = null
        deadline.interval = timeoutMs
        deadline.restart()
        if (withPassword)
            net.connectWithPsk(psk)
        else
            net.connect()
    }
    // Ends the attempt; returns its network (null if it went away)
    function finish(message) {
        deadline.stop()
        const net = target
        busy = false
        target = null
        if (message !== "") {
            error = message
            errorNet = net
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
        // The profile a new network's attempt creates: its UUID, while the
        // object is still there
        function onNmSettingsChanged() {
            root.noteProfile()
        }
    }
    function noteProfile() {
        if (!target || wasKnown || createdUuid !== "")
            return
        const s = target.nmSettings
        if (s && s.length > 0 && typeof s[0].uuid === "string" && uuidPattern.test(s[0].uuid))
            createdUuid = s[0].uuid
    }

    // A new network that did not join leaves no profile behind: forget()
    // when its object is still there, else the profile by the UUID noted
    function forgetNew(net, known) {
        if (known)
            return
        if (net) {
            net.forget()
        } else if (uuidPattern.test(createdUuid)) {
            dropProfile.command = ["sh", "-c", 'exec "$@"', "sh", "nmcli", "connection", "delete", "uuid", createdUuid]
            dropProfile.running = true
        }
        createdUuid = ""
    }
    Process {
        id: dropProfile
    }

    // A signal with no attempt running (a late or repeated one) does nothing
    function failed(reason) {
        if (!target)
            return
        noteProfile()
        const known = wasKnown
        const typed = withPassword
        let net
        if (reason === ConnectionFailReason.NoSecrets && !typed) {
            // A saved network whose kept password no longer works: ask for it
            net = finish("")
            askingNet = net
        } else if (reason === ConnectionFailReason.NoSecrets) {
            net = finish("Senha incorreta")
            askingNet = net
        } else {
            net = finish("Não deu para conectar")
        }
        forgetNew(net, known)
    }

    function joined() {
        if (!target)
            return
        createdUuid = ""
        const net = finish("")
        if (net && isOpen(net)) {
            openPending = net
            openTries = 0
            closeOpenNetwork()
        }
    }

    // Never join an open network by itself. Only a loaded profile with no
    // security part is written (an update made from here goes without the
    // secrets: written on a secured profile it would drop its password, and
    // on one not loaded yet it would empty it). A profile not there yet is
    // tried again, every 0.5 s, for 5 s.
    property var openPending: null
    property int openTries: 0
    function closeOpenNetwork() {
        const net = openPending
        if (!net || !isOpen(net)) {
            openPending = null
            return
        }
        let done = false
        const list = net.nmSettings || []
        for (let i = 0; i < list.length; i++) {
            const m = list[i].read()
            if (m && m.connection !== undefined && m["802-11-wireless-security"] === undefined) {
                list[i].write({ connection: { autoconnect: false } })
                done = true
            }
        }
        if (done || ++openTries >= 10)
            openPending = null
        else
            openRetry.restart()
    }
    Timer {
        id: openRetry
        interval: 500
        onTriggered: root.closeOpenNetwork()
    }

    // 20 s with no answer
    Timer {
        id: deadline
        onTriggered: {
            root.noteProfile()
            const known = root.wasKnown
            const net = root.finish("Não deu para conectar")
            if (net)
                net.disconnect()
            root.forgetNew(net, known)
        }
    }

    // ── A hidden network (nmcli) ──
    // Killed or failed, the script itself undoes what it made: the trap
    // brings the Wi-Fi down and deletes the profile it added (its UUID, once
    // checked), unless the connection came up. nmcli runs in the background
    // and is waited for, so a TERM reaches the trap at once.
    readonly property string hiddenScript: [
        'name="$1"; iface="$2"; uuid=""; pid=""; ok=0',
        'cleanup() {',
        '  [ "$ok" = 1 ] && return',
        '  [ -n "$pid" ] && kill "$pid" 2>/dev/null',
        '  pid=""',
        '  if [ -n "$uuid" ]; then',
        '    nmcli device disconnect "$iface" >/dev/null 2>&1',
        '    nmcli connection delete uuid "$uuid" >/dev/null 2>&1',
        '  fi',
        '  uuid=""',
        '}',
        'trap "cleanup; exit 1" TERM HUP INT',
        'trap cleanup EXIT',
        'IFS= read -r psk || exit 3',
        'out=$(nmcli -t connection add type wifi ifname "$iface" ssid "$name" 802-11-wireless.hidden yes wifi-sec.key-mgmt wpa-psk 2>/dev/null) || exit 4',
        'found=$(printf "%s\\n" "$out" | grep -oE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | head -n 1)',
        'printf "%s\\n" "$found" | grep -qxE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" || exit 5',
        'uuid="$found"',
        'printf "%s\\n" "$psk" | timeout 25 nmcli --ask connection up uuid "$uuid" >/dev/null 2>&1 &',
        'pid=$!',
        'psk=""',
        'wait "$pid" && ok=1',
        '[ "$ok" = 1 ] && exit 0',
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
        targetName = ""
        askingNet = null
        confirmingNet = null
        error = ""
        errorNet = null
        hiddenError = ""
        // The name and the interface as the script's arguments, through sh
        // (always there), so a missing setpriv never puts them in the log
        hidden.command = ["sh", "-c", 'exec setpriv --pdeathsig TERM -- sh -c "$1" sh "$2" "$3"', "sh",
                          hiddenScript, name, iface]
        // Held only until the process starts, then written and wiped
        hidden.input = psk + "\n"
        hidden.stdinEnabled = true
        hidden.running = true
        hiddenDeadline.interval = hiddenTimeoutMs
        hiddenDeadline.restart()
        return ""
    }
    function hiddenDone(ok) {
        hiddenDeadline.stop()
        hidden.input = ""
        busy = false
        hiddenError = ok ? "" : "Não deu para conectar"
    }

    // No reader on its output: nothing of it is kept or logged
    Process {
        id: hidden
        property string input: ""
        onStarted: {
            write(input)
            input = ""
            stdinEnabled = false
        }
        onExited: code => root.hiddenDone(code === 0)
    }
    // Past the deadline the script is stopped (its trap cleans up), and the
    // attempt ends here too, also when the process never started
    Timer {
        id: hiddenDeadline
        onTriggered: {
            hidden.running = false
            root.hiddenDone(false)
        }
    }
}
