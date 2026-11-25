pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/codeaccounts.js" as Accounts
import "../settings/accountphotos.js" as Photos

// The code accounts gh and glab know (settings/codeaccounts.js keeps only
// site, login and which is active) and the switch of gh's active account.
// Read only when asked (refresh: the GitHub section opening, the page),
// never on a timer, never with the screen locked. Each program runs inside
// a fixed bash script: the program's name and arguments are never the
// argv Quickshell starts (bash always is there, so nothing of them reaches
// the log when the program is missing), its error output is dropped, its
// output cut, and it has 8 s. The tokens of the environment stay out, so
// what shows is what gh and glab keep themselves. The raw output is let go
// as soon as it is read; errors are fixed phrases.
Singleton {
    id: root

    property bool ghAvailable: true
    property bool glabAvailable: true
    // gh's accounts, [{ host, users: [{ login, active }] }]
    property var hosts: []
    // glab's (one active account per site, read only)
    property var glabHosts: []
    readonly property bool loading: ghReader.running || glabReader.running
    readonly property bool switching: switcher.running
    property string error: ""
    // A failed switch, kept through the reading after it (until the next
    // switch or clear())
    property string switchError: ""
    readonly property bool locked: LockState.locked || LockState.wanted
    readonly property int folderCount: {
        try {
            return JSON.parse(SettingsStore.get("codeFolders")).length
        } catch (e) {
            return 0
        }
    }

    function activeLogin(host) {
        const e = hosts.find(h => h.host === host)
        const u = e ? e.users.find(x => x.active) : null
        return u ? u.login : ""
    }

    // The wrapper: $1 is the program; missing → 90; timeout → 124
    readonly property string runScript:
        'command -v "$1" >/dev/null 2>&1 || exit 90\n'
        + 'exec 2>/dev/null\n'
        + 'export LC_ALL=C NO_COLOR=1 GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 GH_NO_EXTENSION_UPDATE_NOTIFIER=1\n'
        + 'export GLAB_NO_PROMPT=true GLAB_SEND_TELEMETRY=false GLAB_CHECK_UPDATE=false\n'
        + 'unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_HOST\n'
        + 'unset GITLAB_TOKEN GITLAB_ACCESS_TOKEN OAUTH_TOKEN GL_TOKEN GITLAB_HOST GL_HOST GITLAB_URI GITLAB_API_HOST\n'
        + 'run() { timeout -k 2 8 setpriv --pdeathsig TERM -- "$@" | head -c 65536; return "${PIPESTATUS[0]}"; }\n'
        // An account's public id and login (filling a profile): the login
        // comes by the input, checked again
        + 'if [ "$#" = 3 ] && [ "$1 $2 $3" = "gh api user" ]; then\n'
        + '  IFS= read -r l || exit 1\n'
        + '  [[ $l =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || exit 1\n'
        + '  run gh api "users/$l"; exit $?\n'
        + 'fi\n'
        // The switch: its site and login come by the input, checked again
        + 'if [ "$#" = 3 ] && [ "$1 $2 $3" = "gh auth switch" ]; then\n'
        + '  IFS= read -r h || exit 1; IFS= read -r l || exit 1\n'
        + '  [[ $h =~ ^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$ && $h == *.* && $h != *..* ]] || exit 1\n'
        + '  [[ $l =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || exit 1\n'
        + '  run gh auth switch --hostname "$h" --user "$l"; exit $?\n'
        + 'fi\n'
        + 'if [ "$1" = glab ]; then\n'
        // glab's JSON (stdout) first; an older glab without it: its text,
        // which it writes to the error output
        + '  out=$(run "$@" --all --output json); code=$?\n'
        + '  case "$code" in 124|137) exit 124;; esac\n'
        + '  if [ -n "$out" ]; then printf "%s\\n" "$out"; exit 0; fi\n'
        + '  timeout -k 2 8 setpriv --pdeathsig TERM -- "$@" 2>&1 | head -c 65536; exit 0\n'
        + 'fi\n'
        // An older gh without --json: its text (on the error output)
        + 'if [ "$1 $2 $3 ${4:-}" = "gh auth status --json" ]; then\n'
        + '  out=$(run "$@"); code=$?\n'
        + '  case "$code" in 124|137) exit 124;; esac\n'
        + '  if [ -n "$out" ]; then printf "%s\\n" "$out"; exit "$code"; fi\n'
        + '  timeout -k 2 8 setpriv --pdeathsig TERM -- gh auth status 2>&1 | head -c 65536; exit 0\n'
        + 'fi\n'
        + 'run "$@"\n'

    // Two reads: gh and glab, each one at a time
    property string ghText: ""
    property string glabText: ""
    // A reading asked while another one or a switch runs: again at their end
    property bool refreshAgain: false
    // Bumped by clear(): a reading, switch or photo started before it
    // comes back to nothing
    property int opening: 0
    property int readOpening: 0
    function refresh() {
        if (locked)
            return
        if (ghReader.running || glabReader.running || switcher.running) {
            refreshAgain = true
            return
        }
        error = ""
        ghText = ""
        glabText = ""
        readOpening = opening
        ghReader.running = true
        glabReader.running = true
    }
    Process {
        id: ghReader
        command: ["bash", "-c", root.runScript, "bash", "gh", "auth", "status", "--json", "hosts"]
        stdout: SplitParser {
            onRead: line => root.ghText += line + "\n"
        }
        onExited: (code, status) => {
            const text = root.ghText
            root.ghText = ""
            root.readDone()
            if (root.readOpening !== root.opening)
                return
            root.ghAvailable = code !== 90
            if (code === 90) {
                root.hosts = []
                return
            }
            const model = text.trim().startsWith("{") ? Accounts.parseGhJson(text.trim()) : Accounts.parseGhText(text)
            // gh says nothing at all on a timeout, a failure or a crash
            if ((code !== 0 || status !== 0) && model.length === 0)
                root.error = "Não consegui ler as contas"
            root.hosts = model
        }
    }
    Process {
        id: glabReader
        command: ["bash", "-c", root.runScript, "bash", "glab", "auth", "status"]
        stdout: SplitParser {
            onRead: line => root.glabText += line + "\n"
        }
        onExited: (code, status) => {
            const text = root.glabText
            root.glabText = ""
            root.readDone()
            if (root.readOpening !== root.opening)
                return
            root.glabAvailable = code !== 90
            // A timeout or a crash: the same phrase as gh's
            const failed = code !== 90 && (code === 124 || status !== 0)
            if (failed)
                root.error = "Não consegui ler as contas"
            root.glabHosts = code === 90 || failed ? [] : Accounts.parseGlab(text)
        }
    }

    // The reading asked meanwhile runs once all is done; a clear() before it
    // runs takes it back (it drops refreshAgain)
    function readDone() {
        if (refreshAgain && !ghReader.running && !glabReader.running && !switcher.running) {
            Qt.callLater(() => {
                if (root.refreshAgain) {
                    root.refreshAgain = false
                    root.refresh()
                }
            })
        }
    }
    // The section closed: the reading is let go (a switch only ever comes
    // from the reading of the same opening). The readings and the photo
    // still running are stopped and what they bring back is dropped; a
    // switch already asked of gh is left to end (cut in the middle, gh's
    // file could be left half written), but nothing is read after it
    function clear() {
        opening++
        refreshAgain = false
        if (ghReader.running)
            ghReader.running = false
        if (glabReader.running)
            glabReader.running = false
        ghText = ""
        glabText = ""
        hosts = []
        glabHosts = []
        error = ""
        switchError = ""
        stopPhotos()
        photos = ({})
    }

    // gh's active account of host becomes login: only a pair of the reading
    // on the screen that is not the active one, never with the screen
    // locked, and a second click within 3 s does nothing. The screen then
    // shows what gh says after a new reading, not what was asked
    property double lastSwitch: 0
    property int switchOpening: 0
    property string switchInput: ""
    function switchTo(host, login) {
        const argv = Accounts.switchCommand(hosts, host, login)
        if (argv === null || locked || switcher.running || Date.now() - lastSwitch < 3000)
            return false
        lastSwitch = Date.now()
        switchError = ""
        switchOpening = opening
        // The site and the login go by the input, never in the arguments
        // (the process list shows those)
        switchInput = host + "\n" + login + "\n"
        switcher.stdinEnabled = true
        switcher.running = true
        return true
    }
    // ── An account's id and login, to fill a profile's empty fields ──
    // Only when an account is picked in the editor, one at a time (a new
    // pick takes the place of the one waiting); never locked. The answer
    // is a serial and { id, login } or null (a failure, a timeout, another
    // account): the editor fills nothing then and shows nothing
    signal userRead(int serial, var user)
    property int userSerial: 0
    property string userLogin: ""
    property string userText: ""
    property bool userAgain: false
    function readUser(login) {
        if (locked || !Accounts.validLogin(login))
            return 0
        userSerial++
        userLogin = login
        // One running: this one starts when it ends (its answer is dropped
        // by the editor, whose serial moved on)
        if (userReader.running)
            userAgain = true
        else
            startUser()
        return userSerial
    }
    // The serial and login go with the process when it is asked to start
    // (they may change before it actually runs)
    function startUser() {
        userText = ""
        userReader.serial = userSerial
        userReader.login = userLogin
        userReader.stdinEnabled = true
        userReader.running = true
    }
    Process {
        id: userReader
        property int serial: 0
        property string login: ""
        command: ["bash", "-c", root.runScript, "bash", "gh", "api", "user"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.userText += data
        }
        onRunningChanged: {
            if (running) {
                write(login + "\n")
                stdinEnabled = false
            }
        }
        onExited: (code, status) => {
            const text = root.userText
            root.userText = ""
            const user = code === 0 && status === 0 && !root.locked ? Accounts.parseGhUser(text, login) : null
            root.userRead(serial, user)
            if (root.userAgain) {
                root.userAgain = false
                if (!root.locked)
                    root.startUser()
            }
        }
    }

    // ── Photos (settings/accountphotos.js) ──
    // Fetched one at a time (one queue for the Central and the page), only
    // while one of them shows accounts (watchPhotos), with the photos on
    // in the settings and the screen unlocked; at most 4 an opening. Any
    // failure stops the queue and leaves that account alone for an hour
    // (in memory only). Nothing of an account goes to the log.
    property int photoWatchers: 0
    // One hidden state for the Central and the page, never kept
    property bool photosHidden: false
    readonly property bool photosOn: SettingsStore.get("codePhotos") === true
    property var photos: ({})
    property var photoQueue: []
    property var photoBlocked: ({})
    property int photoBudget: 0
    property string photoLogin: ""
    // Bumped at every stop: the Job that ends after it is not this turn's
    property int photoTurn: 0
    property int photoJobTurn: 0
    readonly property string photoDir: {
        const x = Quickshell.env("XDG_CACHE_HOME") || ""
        const base = /^\/[A-Za-z0-9._\/-]{1,200}$/.test(x) && !x.includes("..") ? x : Quickshell.env("HOME") + "/.cache"
        return base + "/dotfiles/contas-fotos"
    }
    function watchPhotos(on) {
        photoWatchers = Math.max(0, photoWatchers + (on ? 1 : -1))
        if (photoWatchers > 0) {
            photoBudget = 4
            queuePhotos()
        } else {
            // The last one that showed the accounts went: nothing of them
            // stays (the reading, the photos, the hidden state)
            stopPhotos()
            photosHidden = false
            clear()
        }
    }
    // The switch of the photos: on, they are fetched for what shows now;
    // off, a fetch already out is stopped
    onPhotosOnChanged: {
        if (photosOn) {
            photoBudget = 4
            queuePhotos()
        } else {
            stopPhotos()
        }
    }
    // (what the stopped Job brings back is dropped: closed, locked or
    // cleared)
    function stopPhotos() {
        photoTurn++
        photoQueue = []
        photoLogin = ""
        if (photoJob.running)
            photoJob.running = false
    }
    // Locked or asked to lock: what is read, being read or shown is let go
    // (a reading or a switch that ends while locked brings back nothing).
    // Unlocked with the section or the page still showing: read again,
    // once for both
    onLockedChanged: {
        if (locked)
            clear()
        else if (photoWatchers > 0)
            refresh()
    }
    onHostsChanged: queuePhotos()
    // The image of an account ("" for none: the initials show)
    function photoSource(host, login) {
        if (photosHidden || locked || !photosOn)
            return ""
        return photos[Accounts.cacheKeyText(host, login)] ?? ""
    }
    function queuePhotos() {
        if (photoWatchers === 0 || locked || !photosOn)
            return
        const q = photoQueue.slice()
        const now = Date.now()
        // Only github.com: the photo is fetched from there, so the login of
        // another site would ask it for someone else's
        for (const e of hosts.filter(h => h.host === "github.com")) {
            for (const u of e.users) {
                const key = Accounts.cacheKeyText(e.host, u.login)
                if (key !== "" && photos[key] === undefined && !q.includes(u.login) && u.login !== photoLogin
                        && !((photoBlocked[key] ?? 0) > now))
                    q.push(u.login)
            }
        }
        photoQueue = q
        nextPhoto()
    }
    function nextPhoto() {
        if (photoJob.running || photoQueue.length === 0 || photoBudget <= 0 || photoWatchers === 0 || locked || !photosOn)
            return
        const q = photoQueue.slice()
        photoLogin = q.shift()
        photoQueue = q
        photoJobTurn = photoTurn
        photoJob.stdinEnabled = true
        photoJob.running = true
    }
    Process {
        id: photoJob
        command: ["timeout", "-k", "2", "20", "bash", "-c", Photos.SCRIPT, "bash", Quickshell.shellPath(".")]
        stdout: StdioCollector {
            id: photoOut
        }
        stderr: StdioCollector {}
        onRunningChanged: {
            if (running) {
                write(root.photoLogin + "\n")
                stdinEnabled = false
            }
        }
        onExited: code => {
            const key = Accounts.cacheKeyText("github.com", root.photoLogin)
            const word = photoOut.text.trim()
            const same = root.photoJobTurn === root.photoTurn
            root.photoLogin = ""
            // Closed, cleared or locked meanwhile (even if opened again):
            // the cache keeps it, the screen not; the queue of a new
            // opening goes on
            if (root.photoWatchers === 0 || root.locked || !same) {
                root.nextPhoto()
                return
            }
            const src = Photos.source(root.photoDir, word)
            if (src !== "") {
                const m = Object.assign({}, root.photos)
                m[key] = src
                root.photos = m
            }
            // Only downloads count against the 4 of an opening
            if (word.startsWith("ok "))
                root.photoBudget--
            // No account or not an image: remembered for an hour, the queue
            // goes on; the network failed ("stale" keeps the older photo
            // shown): the queue stops too
            if (word === "none" || word === "bad" || src === "" || word.startsWith("stale ")) {
                const b = Object.assign({}, root.photoBlocked)
                b[key] = Date.now() + 3600 * 1000
                root.photoBlocked = b
                if (word !== "none" && word !== "bad") {
                    root.photoQueue = []
                    return
                }
            }
            root.nextPhoto()
        }
    }

    Process {
        id: switcher
        command: ["bash", "-c", root.runScript, "bash", "gh", "auth", "switch"]
        onRunningChanged: {
            if (running) {
                write(root.switchInput)
                stdinEnabled = false
            }
        }
        onExited: (code, status) => {
            root.switchInput = ""
            // Cleared meanwhile: nothing is read for the closed section (a
            // reading asked by a new opening still runs)
            if (root.switchOpening !== root.opening) {
                root.readDone()
                return
            }
            if (code !== 0 || status !== 0)
                root.switchError = "Não consegui trocar de conta"
            root.refreshAgain = false
            root.refresh()
        }
    }
}
