pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../settings/codeaccounts.js" as Accounts

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
        + 'unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GITLAB_TOKEN GL_TOKEN GH_HOST GITLAB_HOST\n'
        + 'run() { timeout -k 2 8 setpriv --pdeathsig TERM -- "$@" | head -c 65536; return "${PIPESTATUS[0]}"; }\n'
        + 'if [ "$1" = glab ]; then\n'
        // glab's JSON (stdout) first; an older glab without it: its text,
        // which it writes to the error output
        + '  out=$(run "$@" --all --output json); code=$?\n'
        + '  [ "$code" = 124 ] && exit 124\n'
        + '  if [ -n "$out" ]; then printf "%s" "$out"; exit 0; fi\n'
        + '  timeout -k 2 8 setpriv --pdeathsig TERM -- "$@" 2>&1 | head -c 65536; exit 0\n'
        + 'fi\n'
        + 'run "$@"\n'

    // Two reads: gh and glab, each one at a time
    property string ghText: ""
    property string glabText: ""
    function refresh() {
        if (locked || ghReader.running || glabReader.running)
            return
        error = ""
        ghText = ""
        glabText = ""
        ghReader.running = true
        glabReader.running = true
    }
    Process {
        id: ghReader
        command: ["bash", "-c", root.runScript, "bash", "gh", "auth", "status", "--json", "hosts"]
        stdout: SplitParser {
            onRead: line => root.ghText += line + "\n"
        }
        onExited: code => {
            const text = root.ghText
            root.ghText = ""
            root.ghAvailable = code !== 90
            if (code === 90) {
                root.hosts = []
                return
            }
            const model = text.trim().startsWith("{") ? Accounts.parseGhJson(text.trim()) : Accounts.parseGhText(text)
            // gh says nothing at all on a timeout or a failure
            if (code !== 0 && model.length === 0)
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
        onExited: code => {
            const text = root.glabText
            root.glabText = ""
            root.glabAvailable = code !== 90
            root.glabHosts = code === 90 || code === 124 ? [] : Accounts.parseGlab(text)
        }
    }

    // gh's active account of host becomes login: only a pair of the reading
    // on the screen that is not the active one, never with the screen
    // locked, and a second click within 3 s does nothing. The screen then
    // shows what gh says after a new reading, not what was asked
    property double lastSwitch: 0
    function switchTo(host, login) {
        const argv = Accounts.switchCommand(hosts, host, login)
        if (argv === null || locked || switcher.running || Date.now() - lastSwitch < 3000)
            return false
        lastSwitch = Date.now()
        error = ""
        switcher.command = ["bash", "-c", runScript, "bash"].concat(argv)
        switcher.running = true
        return true
    }
    Process {
        id: switcher
        onExited: code => {
            if (code !== 0)
                root.error = "Não consegui trocar de conta"
            root.refresh()
        }
    }
}
