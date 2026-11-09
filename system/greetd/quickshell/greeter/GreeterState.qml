pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import "sessions.js" as Sessions
import "../lock/text.js" as Clean

// State of the login screen (runs as the greetd "greeter" user, inside
// cage): the people who can log in, the sessions, the last choices, the
// password through greetd (PAM runs in greetd, as root), power. It reads
// only /etc/passwd (getent), /etc/shells, the two session folders and its
// own cache folder (state.json, and the copy of the background that
// start-greeter checked); it writes only state.json. Nobody's home is read,
// and no user picture is decoded (the initial is shown instead).
//
// The password lives in memory only, between Enter and greetd's prompt; it
// never goes to a log, a file or a binding. greetd's own texts never reach
// the screen: they map to fixed phrases.
Singleton {
    id: root

    // ── Fixed paths (no setting, env or file changes them) ──
    readonly property string stateFile: "/var/cache/qs-greeter/state.json"
    // The background as start-greeter left it: a private copy, already
    // checked (no copy: plain color)
    readonly property string picturePath: "/var/cache/qs-greeter/fundo.png"
    // A greetd session left waiting longer than this (no answer at all) is
    // cancelled and the screen shows an error
    readonly property int checkTimeout: 30000
    readonly property var sessionDirs: [
        { dir: "/usr/share/wayland-sessions", kind: "wayland" },
        { dir: "/usr/share/xsessions", kind: "x11" }
    ]
    // Preferred when a user has no last session
    readonly property string defaultSession: "wayland:hyprland-uwsm.desktop"

    // ── Read by Greeter.qml ──
    property var users: []              // [{ name, display }]
    property int userIndex: 0
    readonly property var current: users.length > 0 ? users[Math.min(userIndex, users.length - 1)] : null
    property var sessions: []           // [{ id, name, command }]
    property string sessionId: ""
    readonly property var session: sessions.find(s => s.id === sessionId) ?? sessions[0] ?? null
    property bool checking: false
    property string error: ""           // "" | "wrong" | "tooMany" | "unknown"
    property int retryMinutes: 0
    property bool capsLock: false
    // The background (start-greeter's checked copy; LockBackground shows the
    // plain color when it is missing)
    readonly property string picture: picturePath
    // Keyboard layout of cage (the install writes it from localectl)
    readonly property string layout: Quickshell.env("XKB_DEFAULT_LAYOUT") || "us"

    // A wrong password: the field clears and shakes
    signal rejected()

    // Between submit() and greetd's prompt only; emptied on every path
    property string pending: ""
    // Set by an error message during the attempt (faillock's lockout)
    property bool sawLockout: false
    property int sawMinutes: 0
    // End of a faillock lockout (ms since the epoch). The greeter cannot read
    // another user's faillock file, so it counts down from what greetd said
    property real lockoutUntil: 0

    // Last user and each user's last session, from state.json
    property var lastSessions: ({})
    // Each list marks itself loaded: a process can still count as running
    // when its output has already ended, so .running is not checked
    property bool usersLoaded: false
    property bool sessionsLoaded: false

    // ── Users ──
    function selectUser(index) {
        if (checking || users.length === 0)
            return
        cancelOpenSession()
        userIndex = (index + users.length) % users.length
        error = ""
        retryMinutes = 0
        lockoutUntil = 0
        const last = lastSessions[current.name]
        sessionId = sessions.some(s => s.id === last) ? last : pickDefaultSession()
    }

    function nextUser(step) {
        selectUser(userIndex + step)
    }

    function selectSession(id) {
        if (!checking && sessions.some(s => s.id === id))
            sessionId = id
    }

    function pickDefaultSession() {
        return sessions.some(s => s.id === defaultSession) ? defaultSession : (sessions[0]?.id ?? "")
    }

    // ── Password, through greetd ──
    function submit(password) {
        if (checking || !current || !session || typeof password !== "string" || password.length === 0)
            return
        pending = password
        checking = true
        error = ""
        sawLockout = false
        sawMinutes = 0
        sessionOpen = true
        Greetd.createSession(current.name)
    }

    // A greetd session still open (between createSession and the launch or
    // a failure) is cancelled before anything else starts
    property bool sessionOpen: false

    function cancelOpenSession() {
        if (!sessionOpen)
            return
        sessionOpen = false
        Greetd.cancelSession()
    }

    // No answer from greetd in time: forget the password and give up
    Timer {
        id: watchdog
        interval: root.checkTimeout
        running: root.checking
        onTriggered: root.failed("unknown")
    }

    // Too many attempts: pam_faillock says so in an error message, in
    // English or in the system language; the minutes come from "(N min…)"
    function readLockout(message) {
        const text = String(message)
        if (/locked|bloquead/i.test(text))
            sawLockout = true
        const minutes = text.match(/\((\d{1,4})\s*min/)
        if (minutes)
            sawMinutes = parseInt(minutes[1])
    }

    function failed(kind) {
        pending = ""
        checking = false
        cancelOpenSession()
        if (kind === "wrong" && sawLockout)
            kind = "tooMany"
        error = kind
        retryMinutes = kind === "tooMany" ? Math.max(1, sawMinutes) : 0
        lockoutUntil = kind === "tooMany" ? Date.now() + retryMinutes * 60000 : 0
        if (kind === "wrong" || kind === "tooMany")
            rejected()
    }

    // While locked out: the minutes left count down, and the field comes
    // back when the time is up or another user is picked. That is only the
    // screen: PAM decides. If the account is still locked, the next try
    // brings the warning back; if it was reset, the next try just works
    function lockoutTick() {
        if (error !== "tooMany")
            return
        const left = lockoutUntil - Date.now()
        if (left <= 0) {
            error = ""
            retryMinutes = 0
            lockoutUntil = 0
        } else {
            retryMinutes = Math.ceil(left / 60000)
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.error === "tooMany"
        onTriggered: root.lockoutTick()
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, isError, responseRequired, echoResponse) {
            if (isError) {
                root.readLockout(message)
                return
            }
            if (!responseRequired)
                return
            // A visible prompt (a user name, a code): never answer it with
            // the password
            if (echoResponse || root.pending === "") {
                root.failed("unknown")
                return
            }
            const password = root.pending
            root.pending = ""
            Greetd.respond(password)
        }

        function onAuthFailure(message) {
            root.readLockout(message)
            root.failed("wrong")
        }

        // Only while checking: a cancel of ours can also end in an error
        function onError(text) {
            if (root.checking)
                root.failed("unknown")
        }

        // Saves the choices, then starts the session; the greeter quits.
        // greetd joins the words with spaces and runs them through sh -c,
        // so each one goes quoted
        function onReadyToLaunch() {
            root.pending = ""
            root.sessionOpen = false
            root.saveState()
            Greetd.launch(Sessions.shellQuote(root.session.command), [], true)
        }
    }

    // ── state.json: the id of each user's last session, the last user ──
    FileView {
        id: stateView
        path: root.stateFile
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }

    // Up to 8 KB; anything odd is ignored
    function parseState(text) {
        const out = { lastUser: "", sessions: {} }
        if (typeof text !== "string" || text.length === 0 || text.length > 8192)
            return out
        let j
        try {
            j = JSON.parse(text)
        } catch (e) {
            return out
        }
        if (j === null || typeof j !== "object" || Array.isArray(j))
            return out
        if (typeof j.lastUser === "string" && j.lastUser.length <= 64)
            out.lastUser = j.lastUser
        if (j.sessions !== null && typeof j.sessions === "object" && !Array.isArray(j.sessions)) {
            for (const name of Object.keys(j.sessions).slice(0, 64)) {
                if (typeof j.sessions[name] === "string" && j.sessions[name].length <= 128)
                    out.sessions[name] = j.sessions[name]
            }
        }
        return out
    }

    function saveState() {
        if (!current || !session)
            return
        const sessions = {}
        // Only the people still listed
        for (const u of users) {
            if (lastSessions[u.name])
                sessions[u.name] = lastSessions[u.name]
        }
        sessions[current.name] = session.id
        stateView.setText(JSON.stringify({ lastUser: current.name, sessions: sessions }) + "\n")
    }

    // ── Loading ──
    // Users: UID 1000–59999 with a login shell from /etc/shells (not
    // nologin or false); the name as the user name rules allow it
    FileView {
        id: shellsView
        path: "/etc/shells"
        blockLoading: true
        printErrors: false
    }

    Process {
        id: readUsers
        command: ["getent", "passwd"]
        stdout: StdioCollector {
            onStreamFinished: root.loadUsers(text)
        }
    }

    function loadUsers(text) {
        const shells = shellsView.text().split("\n").map(s => s.trim()).filter(s => s.startsWith("/"))
        const list = []
        for (const line of text.split("\n")) {
            const f = line.split(":")
            if (f.length < 7)
                continue
            const uid = parseInt(f[2])
            const shell = f[6]
            if (!(uid >= 1000 && uid <= 59999) || !/^[a-z_][a-z0-9_-]{0,31}$/.test(f[0]))
                continue
            if (!shells.includes(shell) || /(nologin|false)$/.test(shell))
                continue
            const gecos = Clean.clean((f[4] || "").split(",")[0], 60)
            list.push({
                name: f[0],
                display: gecos !== "" ? gecos : f[0]
            })
        }
        // Two people shown with the same name: add the login to both
        const seen = {}
        for (const u of list)
            seen[u.display.toLowerCase()] = (seen[u.display.toLowerCase()] || 0) + 1
        for (const u of list) {
            if (seen[u.display.toLowerCase()] > 1 && u.display !== u.name)
                u.display = `${u.display} (${u.name})`
        }
        users = list
        usersLoaded = true
        finishLoading()
    }

    // Sessions: every .desktop of the two folders (regular files only), with
    // a TryExec that resolves
    Process {
        id: readSessions
        command: ["sh", "-c",
            'for d in "$@"; do for f in "$d"/*.desktop; do '
            + '[ -f "$f" ] && [ ! -L "$f" ] || continue; '
            + 'printf "\\036%s\\037%s\\037" "$d" "${f##*/}"; head -c 16384 -- "$f"; done; done',
            "sh"].concat(root.sessionDirs.map(s => s.dir))
        stdout: StdioCollector {
            onStreamFinished: root.loadSessions(text)
        }
    }

    property var candidates: []

    function loadSessions(text) {
        const list = []
        for (const record of text.split("\x1e")) {
            const parts = record.split("\x1f")
            if (parts.length < 3)
                continue
            const where = sessionDirs.find(s => s.dir === parts[0])
            if (!where)
                continue
            const s = Sessions.session(parts[1], parts.slice(2).join("\x1f"), where.kind)
            if (s)
                list.push(s)
        }
        candidates = list
        const tries = list.map(s => s.tryExec).filter(t => t !== "")
        if (tries.length === 0) {
            sessions = list
            sessionsLoaded = true
            finishLoading()
            return
        }
        checkTryExec.command = ["sh", "-c",
            'for t in "$@"; do command -v -- "$t" >/dev/null 2>&1 && echo "$t"; done', "sh"].concat(tries)
        checkTryExec.running = true
    }

    Process {
        id: checkTryExec
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n")
                root.sessions = root.candidates.filter(s => s.tryExec === "" || found.includes(s.tryExec))
                root.sessionsLoaded = true
                root.finishLoading()
            }
        }
    }

    // Both lists in: open on the last user and their last session
    function finishLoading() {
        if (!usersLoaded || !sessionsLoaded)
            return
        stateView.reload()
        const saved = parseState(stateView.text())
        lastSessions = saved.sessions
        const i = users.findIndex(u => u.name === saved.lastUser)
        userIndex = i >= 0 ? i : 0
        if (current) {
            const last = lastSessions[current.name]
            sessionId = sessions.some(s => s.id === last) ? last : pickDefaultSession()
        }
    }

    // ── Power: suspend at once; reboot and power off after a second click
    // (Greeter.qml) ──
    function power(action) {
        if (action === "suspend" || action === "reboot" || action === "poweroff")
            Quickshell.execDetached(["systemctl", action])
    }

    // ── Caps Lock: the keyboard LEDs, read every 300 ms ──
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
        running: root.ledPaths.length > 0
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

    Component.onCompleted: {
        readUsers.running = true
        readSessions.running = true
        findLeds.running = true
    }
}
