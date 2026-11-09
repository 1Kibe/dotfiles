pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.theme

// State of the lock screen (lock/LockScreen.qml): the lock request, the
// password check through PAM, too many attempts (faillock), Caps Lock and the
// keyboard layout. The password only lives in memory, between Enter and the
// PAM prompt; it never goes to a log, a file, the IPC or a binding.
//
// - Locking: lock() asks; `locked` turns true only when the compositor says
//   every screen is covered (WlSessionLock.secure, set by LockScreen).
// - Unlocking: only a PAM success, never the IPC.
// - PAM: the fixed service quickshell-lock (system/pam.d), the session's own
//   user. Nothing here can change either.
Singleton {
    id: root

    // ── Read by lock/LockScreen.qml and the IPC (shell.qml) ──
    // Asked to lock: WlSessionLock.locked follows it. Starts from the marker,
    // read synchronously, so a Quickshell reload or restart while locked
    // never sees "unlocked" for a moment (the lock survives the reload and
    // would follow a false here). Only a PAM success sets it back to false.
    property bool wanted: markerFile !== "" && marker.text().startsWith("locked")
    property bool locked: false           // the compositor's confirmation (set by LockScreen)
    property bool unlocking: false        // PAM said yes: the content fades, then the lock ends
    property bool checking: false         // PAM running: keys ignored
    property string error: ""             // "" | "wrong" | "tooMany" | "unknown" | "marker" (not locked)
    property int retryMinutes: 0          // left on a faillock lockout
    property bool capsLock: false
    property bool typing: false           // some field has text (dots, no count)
    property string layout: ""            // keyboard layout of the main keyboard ("br")
    property string displayName: user     // full name from passwd, else the login name

    readonly property string pamService: "quickshell-lock"
    readonly property string user: Quickshell.env("USER") || ""
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    // Present while locked: a Quickshell that starts and finds it locks at
    // once (it died while the screen was locked)
    readonly property string markerFile: runtimeDir !== "" ? `${runtimeDir}/qs-lock-ativo` : ""
    // AccountsService picture; the user card falls back to the initial
    readonly property string photo: user !== "" ? `/var/lib/AccountsService/icons/${user}` : ""

    // A wrong password: the fields clear and shake
    signal rejected()

    // Between submit() and the PAM prompt only; emptied on every path
    property string pending: ""

    // ── Locking ──
    // Super+L (hypr-travar), hypridle, the marker at start. Asking again
    // while locked does nothing.
    function lock() {
        if (wanted)
            return
        // Nothing of the session stays open over or under the lock
        ShellState.close()
        ClipboardStore.close()
        if (CaptureState.open)
            CaptureState.close()
        // A screen recording stops (saved as usual) so it does not film the lock
        CaptureState.stopRecord()
        error = ""
        retryMinutes = 0
        checking = false
        unlocking = false
        typing = false
        pending = ""
        // The marker first: without it a reload while locked would fall to
        // Hyprland's "lockdead" screen, so no marker, no lock
        if (!writeMarker()) {
            console.warn("lock: o marcador não foi gravado; a tela não foi travada")
            error = "marker"
            return
        }
        readLayout.running = true
        wanted = true
    }

    // Written blocking, then read back from disk by a new FileView (the
    // one that wrote answers from its own memory, even when the write
    // failed). The text carries a new stamp every time: FileView skips a
    // write whose text equals what it already holds, and the unlock removes
    // the file behind its back.
    function writeMarker() {
        if (markerFile === "")
            return false
        const stamp = `locked ${Date.now()}`
        marker.setText(`${stamp}\n`)
        const check = freshView.createObject(root, { path: markerFile })
        const onDisk = check.text()
        check.destroy()
        return onDisk.startsWith(stamp)
    }

    // A reader with no memory of earlier reads, for writeMarker()
    Component {
        id: freshView
        FileView {
            blockLoading: true
            printErrors: false
        }
    }

    // Present ("locked <stamp>") while the screen is locked; in
    // XDG_RUNTIME_DIR (700)
    FileView {
        id: marker
        path: root.markerFile
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    // ── Password ──
    // One PAM attempt per Enter. An empty field, a check already running or
    // a faillock lockout do not reach PAM.
    function submit(password) {
        if (!wanted || unlocking || checking || password.length === 0 || error === "tooMany")
            return
        error = ""
        pending = password
        checking = true
        if (!pam.start()) {
            pending = ""
            checking = false
            error = "unknown"
        }
    }

    // Esc in the field: the message goes, the lockout message stays
    function clear() {
        if (error !== "tooMany")
            error = ""
    }

    function stats() {
        return { locked: locked, checking: checking, dimmed: false, error: error }
    }

    PamContext {
        id: pam
        config: root.pamService
        configDirectory: "/etc/pam.d"

        // Only the hidden prompt gets the password. A visible prompt (a user
        // name) or a second prompt is not answered: the attempt ends as an
        // error. PAM's own texts are never shown.
        onPamMessage: {
            if (!responseRequired)
                return
            if (responseVisible || root.pending === "") {
                root.pending = ""
                abort()
                root.finish("unknown")
                return
            }
            const answer = root.pending
            root.pending = ""
            respond(answer)
        }

        onCompleted: result => {
            root.pending = ""
            if (result === PamResult.Success) {
                root.checking = false
                root.error = ""
                root.unlocking = true
                fadeOut.restart()
            } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                // A locked account also comes as Failed: faillock tells
                // which one it was
                readFaillock.running = true
            } else {
                root.finish("unknown")
            }
        }
    }

    function finish(err) {
        checking = false
        error = err
        if (err !== "")
            rejected()
    }

    // The content fades out, then the lock ends (LockScreen drops the
    // surfaces) and the marker goes
    Timer {
        id: fadeOut
        interval: Theme.animNormal
        onTriggered: {
            root.wanted = false
            root.unlocking = false
            root.typing = false
            if (root.markerFile !== "")
                Quickshell.execDetached(["rm", "-f", "--", root.markerFile])
        }
    }

    // ── Too many attempts (pam_faillock) ──
    // The limits of faillock.conf (Arch defaults when unset: 3 failures in
    // 900 s lock for 600 s), the clock, then this user's failures. The tally
    // file belongs to the user, so no root is needed.
    readonly property string faillockScript:
        'v() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" /etc/security/faillock.conf 2>/dev/null | tail -1; }\n'
        + 'echo "conf $(v deny) $(v fail_interval) $(v unlock_time) $(date +%s)"\n'
        + 'faillock --user "$1" 2>/dev/null'

    Process {
        id: readFaillock
        command: ["sh", "-c", root.faillockScript, "sh", root.user]
        stdout: StdioCollector {
            onStreamFinished: root.faillockRead(text)
        }
    }

    function faillockRead(text) {
        const lines = text.split("\n")
        const conf = (lines[0] || "").split(" ")
        const deny = parseInt(conf[1]) || 3
        const interval = parseInt(conf[2]) || 900
        const unlockTime = parseInt(conf[3]) || 600
        const now = parseInt(conf[4]) || Math.floor(Date.now() / 1000)
        // "2026-11-09 11:36:12 TTY /dev/tty2 V": valid failures in the window
        let count = 0
        let last = 0
        for (const line of lines) {
            const m = line.match(/^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\s.*\sV\s*$/)
            if (!m)
                continue
            // Local time, built from the parts (a date string without a zone
            // is not read the same way everywhere)
            const t = Math.floor(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() / 1000)
            if (now - t <= interval) {
                count++
                last = Math.max(last, t)
            }
        }
        const left = last + unlockTime - now
        if (count >= deny && left > 0) {
            retryMinutes = Math.ceil(left / 60)
            finish("tooMany")
        } else {
            retryMinutes = 0
            finish("wrong")
        }
    }

    // While locked out, read again every 30 s: the message counts down and
    // the field comes back when the time is up
    Timer {
        interval: 30000
        repeat: true
        running: root.wanted && root.error === "tooMany"
        onTriggered: recheck.running = true
    }

    Process {
        id: recheck
        command: ["sh", "-c", root.faillockScript, "sh", root.user]
        stdout: StdioCollector {
            onStreamFinished: {
                root.faillockRead(text)
                // Still locked out keeps "tooMany"; otherwise a clean field
                if (root.error === "wrong")
                    root.error = ""
            }
        }
    }

    // ── Caps Lock ──
    // The keyboard LEDs (one per keyboard), read every 300 ms only while
    // locked: on if any of them is on
    property var ledPaths: []

    Process {
        id: findLeds
        command: ["sh", "-c", 'for f in /sys/class/leds/*::capslock/brightness; do [ -r "$f" ] && echo "$f"; done']
        stdout: StdioCollector {
            onStreamFinished: root.ledPaths = text.split("\n").filter(p => p !== "")
        }
    }

    Variants {
        id: leds
        model: root.ledPaths

        FileView {
            required property string modelData
            path: modelData
            printErrors: false
        }
    }

    Timer {
        interval: 300
        repeat: true
        running: root.wanted && root.ledPaths.length > 0
        triggeredOnStart: true
        onTriggered: {
            let on = false
            for (const led of leds.instances) {
                led.reload()
                if (led.text().trim() !== "" && led.text().trim() !== "0")
                    on = true
            }
            root.capsLock = on
        }
    }

    // ── Keyboard layout and name ──
    // The layout of the main keyboard at lock time ("br"); the active one
    // when there are several
    Process {
        id: readLayout
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main) ?? null
                    if (kb) {
                        const layouts = (kb.layout || "").split(",")
                        root.layout = layouts[kb.active_layout_index ?? 0] || layouts[0] || ""
                    }
                } catch (e) {
                    root.layout = ""
                }
            }
        }
    }

    // Full name from the GECOS field of passwd (before the first comma)
    Process {
        id: readName
        command: ["getent", "passwd", root.user]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] || "").split(",")[0].trim()
                if (gecos !== "")
                    root.displayName = gecos
            }
        }
    }

    Component.onCompleted: {
        findLeds.running = true
        if (user !== "")
            readName.running = true
        // Started (or reloaded) with the marker: `wanted` is already true and
        // the new lock takes over the old or dead one
        // (allow_session_lock_restore); only the layout is read again
        if (wanted)
            readLayout.running = true
    }
}
